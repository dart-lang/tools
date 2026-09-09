// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

import 'char_codes.dart';
import 'editor.dart';
import 'equality.dart';
import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';
import 'wrap.dart';

/// Performs the string operation on [yamlEdit] to achieve the effect of setting
/// the element at [key] to [newValue] when re-parsed.
SourceEdit updateInMap(
    YamlEditor yamlEdit, YamlMap map, Object? key, YamlNode newValue) {
  if (!containsKey(map, key)) {
    final keyNode = wrapAsYamlNode(key);

    if (map.style == CollectionStyle.FLOW) {
      return _addToFlowMap(yamlEdit, map, keyNode, newValue);
    } else {
      return _addToBlockMap(yamlEdit, map, keyNode, newValue);
    }
  } else {
    if (map.style == CollectionStyle.FLOW) {
      return _replaceInFlowMap(yamlEdit, map, key, newValue);
    } else {
      return _replaceInBlockMap(yamlEdit, map, key, newValue);
    }
  }
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the element at [key] when re-parsed.
SourceEdit removeInMap(YamlEditor yamlEdit, YamlMap map, Object? key) {
  assert(containsKey(map, key));

  if (map.style == CollectionStyle.FLOW) {
    return _removeFromFlowMap(yamlEdit, map, key);
  } else {
    return _removeFromBlockMap(yamlEdit, map, key);
  }
}

/// Performs the string operation on [yamlEdit] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a
/// block map.
SourceEdit _addToBlockMap(
    YamlEditor yamlEdit, YamlMap map, Object key, YamlNode newValue) {
  final yaml = yamlEdit.toString();
  final newIndentation =
      getMapIndentation(yaml, map) + getIndentation(yamlEdit);
  final keyString = yamlEncodeFlow(wrapAsYamlNode(key));
  final lineEnding = getLineEnding(yaml);

  var formattedValue = ' ' * getMapIndentation(yaml, map);
  var offset = map.span.end.offset;

  final insertionIndex = getMapInsertionIndex(map, keyString);

  if (map.isNotEmpty) {
    /// Adjusts offset to after the trailing newline of the last entry, if it
    /// exists
    if (insertionIndex == map.length) {
      final lastKey = map.nodes.keys.last;
      final lastValueSpanEnd =
          yamlEdit.getTrueContentSensitiveEnd(map, lastKey);
      final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);

      if (nextNewLineIndex != -1) {
        offset = nextNewLineIndex + 1;
      } else {
        formattedValue = lineEnding + formattedValue;
      }
    } else {
      final keyAtIndex = map.nodes.keys.toList()[insertionIndex] as YamlNode;
      final keySpanStart = keyAtIndex.span.start.offset;
      final prevNewLineIndex = yaml.lastIndexOf('\n', keySpanStart);

      offset = prevNewLineIndex + 1;
    }
  }

  var valueString = yamlEncodeBlock(newValue, newIndentation, lineEnding);
  if (isCollection(newValue) &&
      !isFlowYamlCollectionNode(newValue) &&
      !isEmpty(newValue)) {
    formattedValue += '$keyString:$lineEnding$valueString$lineEnding';
  } else {
    formattedValue += '$keyString: $valueString$lineEnding';
  }

  return SourceEdit(offset, 0, formattedValue);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of adding
/// the [keyNode]:[newValue] pair when reparsed, bearing in mind that this is a
/// flow map.
SourceEdit _addToFlowMap(
    YamlEditor yamlEdit, YamlMap map, YamlNode keyNode, YamlNode newValue) {
  final keyString = yamlEncodeFlow(keyNode);
  final valueString = yamlEncodeFlow(newValue);

  // The -1 accounts for the closing bracket.
  if (map.isEmpty) {
    return SourceEdit(map.span.end.offset - 1, 0, '$keyString: $valueString');
  }

  final insertionIndex = getMapInsertionIndex(map, keyString);

  if (insertionIndex == map.length) {
    final yaml = yamlEdit.toString();
    final lastNode = map.nodes.values.last;
    final closingOffset = map.span.end.offset - 1;
    final between = yaml.substring(lastNode.span.end.offset, closingOffset);
    final hasTrailing = betweenHasTrailingComma(between);

    final entryString = '$keyString: $valueString';
    String formattedValue;
    if (hasTrailing) {
      // If there is already a trailing comma in the flow map, do not prepend
      // another comma. If the flow map spans multiple lines with the closing
      // brace on a new line, align the new entry with the previous elements.
      if (between.contains('\n')) {
        final lastKey = map.nodes.keys.last as YamlNode;
        formattedValue = formatMultilineFlowTrailingEntry(
          closingOffset: closingOffset,
          lastEntryStartOffset: lastKey.span.start.offset,
          newEntry: entryString,
          yaml: yaml,
        );
      } else {
        var v = entryString;
        if (!RegExp(r'\s$').hasMatch(between)) {
          v = ' $v';
        }
        formattedValue = '$v,';
      }
    } else {
      formattedValue = ', $entryString';
    }

    return SourceEdit(closingOffset, 0, formattedValue);
  }

  final insertionOffset =
      (map.nodes.keys.toList()[insertionIndex] as YamlNode).span.start.offset;

  return SourceEdit(insertionOffset, 0, '$keyString: $valueString, ');
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// replacing the value at [key] with [newValue] when reparsed, bearing in mind
/// that this is a block map.
SourceEdit _replaceInBlockMap(
    YamlEditor yamlEdit, YamlMap map, Object? key, YamlNode newValue) {
  final yaml = yamlEdit.toString();
  final lineEnding = getLineEnding(yaml);
  final newIndentation =
      getMapIndentation(yaml, map) + getIndentation(yamlEdit);

  final keyNode = getKeyNode(map, key);
  var valueAsString =
      yamlEncodeBlock(wrapAsYamlNode(newValue), newIndentation, lineEnding);
  if (isCollection(newValue) &&
      !isFlowYamlCollectionNode(newValue) &&
      !isEmpty(newValue)) {
    valueAsString = lineEnding + valueAsString;
  }

  final anchorTag = yamlEdit.getAnchorTag(map, key);
  if (anchorTag != null) {
    if (valueAsString.startsWith(lineEnding)) {
      valueAsString = ' $anchorTag$valueAsString';
    } else {
      valueAsString = ' $anchorTag ${valueAsString.trimLeft()}';
    }
  } else if (!valueAsString.startsWith(lineEnding)) {
    // prepend whitespace to ensure there is space after colon.
    valueAsString = ' $valueAsString';
  }

  /// Find the association colon after the key, skipping whitespace and
  /// comments. Throws [UnsupportedError] if no colon exists for this key
  /// (e.g. an explicit key without a value).
  final colonIndex = _findAssociationColon(yaml, keyNode.span.end.offset);
  if (colonIndex == -1) {
    throw UnsupportedError('Association colon not found after key');
  }
  final start = colonIndex + 1;
  var end = yamlEdit.getTrueContentSensitiveEnd(map, key);

  /// `package:yaml` parses empty nodes in a way where the start/end of the
  /// empty value node is the end of the key node, so we have to adjust for
  /// this.
  if (end < start) end = start;

  return SourceEdit(start, end - start, valueAsString);
}

/// Finds the index of the association colon (`:`) belonging to a key in
/// [yaml], starting from [startOffset].
///
/// Skips whitespace and comments. Returns `-1` if no colon is found before
/// encountering another token or reaching the end of the input.
int _findAssociationColon(String yaml, int startOffset) {
  var i = startOffset;
  while (i < yaml.length) {
    final c = yaml.codeUnitAt(i);
    if (YamlChar.isWhitespace(c) || YamlChar.isLineBreak(c)) {
      i++;
    } else if (c == YamlChar.hash) {
      i++;
      while (i < yaml.length && !YamlChar.isLineBreak(yaml.codeUnitAt(i))) {
        i++;
      }
    } else if (c == YamlChar.colon) {
      return i;
    } else {
      return -1;
    }
  }
  return -1;
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// replacing the value at [key] with [newValue] when reparsed, bearing in mind
/// that this is a flow map.
SourceEdit _replaceInFlowMap(
    YamlEditor yamlEdit, YamlMap map, Object? key, YamlNode newValue) {
  final valueSpan = yamlEdit.getTrueSpan(map, key);
  var valueString = yamlEncodeFlow(newValue);
  final anchorTag = yamlEdit.getAnchorTag(map, key);
  if (anchorTag != null) {
    valueString = '$anchorTag $valueString';
  }

  final yaml = yamlEdit.toString();
  final keyNode = getKeyNode(map, key);
  final colonIndex = findNextFlowDelimiter(
    yaml,
    keyNode.span.end.offset,
    delimiters: {YamlChar.colon, YamlChar.comma, YamlChar.rightCurly},
  );
  if (colonIndex == -1 || yaml.codeUnitAt(colonIndex) != YamlChar.colon) {
    throw UnsupportedError('Association colon not found after key');
  }

  var start = valueSpan.start.offset;
  if (valueSpan.length == 0) {
    if (start < colonIndex + 1) {
      start = colonIndex + 1;
    }
    if (start <= colonIndex + 1) {
      valueString = ' $valueString';
    }
  }

  return SourceEdit(start, valueSpan.length, valueString);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [key] from the map, bearing in mind that this is a block
/// map.
SourceEdit _removeFromBlockMap(YamlEditor yamlEdit, YamlMap map, Object? key) {
  final (index: entryIndex, :keyNode, :valueNode) = getYamlMapEntry(map, key);
  final yaml = yamlEdit.toString();
  final mapSize = map.length;
  final keySpan = keyNode.span;

  // If the map itself has a header preceding the first key (such as an anchor
  // `&mapAnchor` or a type tag `!tag`), removing the first entry must not
  // delete the map header, so we start at the key's span rather than the map's
  // start span.
  final hasMapHeader = map.span.start.offset < keySpan.start.offset &&
      (() {
        final prefix = yaml
            .substring(map.span.start.offset, keySpan.start.offset)
            .trimLeft();
        return prefix.startsWith('&') || prefix.startsWith('!');
      })();

  return removeBlockCollectionEntry(
    yaml,
    blockCollection: map,
    collectionIndent: getMapIndentation(yaml, map),
    isFirstEntry: entryIndex == 0 && !hasMapHeader,
    isSingleEntry: mapSize == 1,
    isLastEntry: entryIndex >= mapSize - 1,
    nodeToRemoveOffset: (
      // A block map only exists because of its first key.
      start: entryIndex == 0 && !hasMapHeader
          ? map.span.start.offset
          : keySpan.start.offset,
      end: valueNode.span.length == 0
          ? keySpan.end.offset + 2 // Null value have no span. Skip ":".
          : yamlEdit.getTrueContentSensitiveEnd(map, key),
    ),
    lineEnding: getLineEnding(yaml),

    // Only called when the next node is present. Never before.
    nextBlockNodeInfo: () {
      final nextKeyNode = map.nodes.keys.elementAt(entryIndex + 1) as YamlNode;
      final nextKeySpan = nextKeyNode.span.start;

      return (
        nearestLineEnding: yaml.lastIndexOf('\n', nextKeySpan.offset),
        nextNodeColStart: nextKeySpan.column
      );
    },
  );
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [key] from the map, bearing in mind that this is a flow
/// map.
SourceEdit _removeFromFlowMap(YamlEditor yamlEdit, YamlMap map, Object? key) {
  final (index: _, :keyNode, :valueNode) = getYamlMapEntry(map, key);

  var start = keyNode.span.start.offset;
  var end = yamlEdit.getTrueSpan(map, key, valueNode).end.offset;
  final yaml = yamlEdit.toString();

  if (deepEquals(keyNode, map.keys.first)) {
    start = findPreviousFlowDelimiter(
          yaml,
          start - 1,
          delimiters: {YamlChar.leftCurly},
        ) +
        1;

    if (deepEquals(keyNode, map.keys.last)) {
      end = findNextFlowDelimiter(
        yaml,
        end,
        delimiters: {YamlChar.rightCurly},
      );
    } else {
      end = findNextFlowDelimiter(
            yaml,
            end,
            delimiters: {YamlChar.comma},
          ) +
          1;
    }
  } else {
    start = findPreviousFlowDelimiter(
      yaml,
      start - 1,
      delimiters: {YamlChar.comma},
    );
  }

  return SourceEdit(start, end - start, '');
}
