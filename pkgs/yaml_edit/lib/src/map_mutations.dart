// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

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
      final lastValueSpanEnd = getContentSensitiveEnd(map.nodes.values.last);
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

  final keyAtIndex = map.nodes.keys.toList()[insertionIndex] as YamlNode;
  final insertionOffset = keyAtIndex.span.start.offset;

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

  if (!valueAsString.startsWith(lineEnding)) {
    // prepend whitespace to ensure there is space after colon.
    valueAsString = ' $valueAsString';
  }

  final colon = map.colonSpan(keyNode);
  final start = colon != null ? colon.end.offset : keyNode.span.end.offset + 1;
  var end = getContentSensitiveEnd(map.nodes[keyNode] ?? map.nodes[key]!);

  if (end < start) end = start;

  if (valueAsString.trimLeft().startsWith('|') ||
      valueAsString.trimLeft().startsWith('>')) {
    final targetNode = map.nodes[keyNode] ?? map.nodes[key] ?? keyNode;
    final (:replacement, :endOffset) = preserveTrailingCommentOnBlockScalar(
      oldNode: targetNode,
      yaml: yaml,
      replacement: valueAsString,
      currentEndOffset: end,
      lineEnding: lineEnding,
      blockIndent: getMapIndentation(yaml, map),
    );
    valueAsString = replacement;
    end = endOffset;
  }

  return SourceEdit(start, end - start, valueAsString);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// replacing the value at [key] with [newValue] when reparsed, bearing in mind
/// that this is a flow map.
SourceEdit _replaceInFlowMap(
    YamlEditor yamlEdit, YamlMap map, Object? key, YamlNode newValue) {
  final keyNode = getKeyNode(map, key);
  final colon = map.colonSpan(keyNode);
  final valueSpan = (map.nodes[keyNode] ?? map.nodes[key]!).span;
  final valueString = yamlEncodeFlow(newValue);
  final offset = colon != null ? colon.end.offset : valueSpan.start.offset;
  final length = colon != null
      ? (valueSpan.end.offset - colon.end.offset)
      : valueSpan.length;
  final replacement = colon != null && !valueString.startsWith(' ')
      ? ' $valueString'
      : valueString;

  return SourceEdit(offset, length, replacement);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [key] from the map, bearing in mind that this is a block
/// map.
SourceEdit _removeFromBlockMap(YamlEditor yamlEdit, YamlMap map, Object? key) {
  final (index: entryIndex, :keyNode, :valueNode) = getYamlMapEntry(map, key);
  final yaml = yamlEdit.toString();
  final mapSize = map.length;
  final keySpan = keyNode.span;

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
      start: entryIndex == 0 && !hasMapHeader
          ? map.span.start.offset
          : keySpan.start.offset,
      end: valueNode.span.length == 0
          ? (map.colonSpan(keyNode)?.end.offset ?? keySpan.end.offset + 2)
          : getContentSensitiveEnd(valueNode),
    ),
    lineEnding: getLineEnding(yaml),
    nextBlockNodeInfo: () {
      final nextKeyNode = map.nodes.keys.elementAt(entryIndex + 1) as YamlNode;
      final nextKeySpan = nextKeyNode.span.start;

      return (
        nearestLineEnding: yaml.lastIndexOf('\n', nextKeySpan.offset),
        nextNodeColStart: nextKeySpan.column,
      );
    },
  );
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [key] from the map, bearing in mind that this is a flow
/// map.
SourceEdit _removeFromFlowMap(YamlEditor yamlEdit, YamlMap map, Object? key) {
  final (index: entryIndex, :keyNode, :valueNode) = getYamlMapEntry(map, key);

  if (map.length == 1) {
    final start = map.openSpan != null
        ? map.openSpan!.end.offset
        : (map.span.start.offset + 1);
    final end = map.closeSpan != null
        ? map.closeSpan!.start.offset
        : (map.span.end.offset - 1);
    return SourceEdit(start, end - start, '');
  }

  final entrySpan = map.entrySpan(keyNode);
  if (entrySpan != null) {
    final start = (entryIndex == 0 && map.openSpan != null)
        ? map.openSpan!.end.offset
        : entrySpan.start.offset;
    return SourceEdit(start, entrySpan.end.offset - start, '');
  }

  var start = keyNode.span.start.offset;
  var end = valueNode.span.end.offset;
  final yaml = yamlEdit.toString();

  if (entryIndex == 0) {
    start = yaml.lastIndexOf('{', start - 1) + 1;
    if (map.length == 1) {
      end = yaml.indexOf('}', end);
    } else {
      end = yaml.indexOf(',', end) + 1;
    }
  } else {
    start = yaml.lastIndexOf(',', start - 1);
  }

  return SourceEdit(start, end - start, '');
}
