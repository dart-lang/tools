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
  final keyNode = getKeyNode(map, key);
  final valueNode = map.nodes[keyNode]!;

  if (map.style == CollectionStyle.FLOW) {
    return _removeFromFlowMap(yamlEdit, map, keyNode, valueNode);
  } else {
    return _removeFromBlockMap(yamlEdit, map, keyNode, valueNode);
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
    return SourceEdit(map.span.end.offset - 1, 0, ', $keyString: $valueString');
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

  if (!valueAsString.startsWith(lineEnding)) {
    // prepend whitespace to ensure there is space after colon.
    valueAsString = ' $valueAsString';
  }

  /// +1 accounts for the colon
  // TODO: What if here is a whitespace following the key, before the colon?
  final start = keyNode.span.end.offset + 1;
  var end = getContentSensitiveEnd(map.nodes[key]!);

  /// `package:yaml` parses empty nodes in a way where the start/end of the
  /// empty value node is the end of the key node, so we have to adjust for
  /// this.
  if (end < start) end = start;

  return SourceEdit(start, end - start, valueAsString);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// replacing the value at [key] with [newValue] when reparsed, bearing in mind
/// that this is a flow map.
SourceEdit _replaceInFlowMap(
    YamlEditor yamlEdit, YamlMap map, Object? key, YamlNode newValue) {
  final valueSpan = map.nodes[key]!.span;
  final valueString = yamlEncodeFlow(newValue);

  return SourceEdit(valueSpan.start.offset, valueSpan.length, valueString);
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [keyNode] from the map, bearing in mind that this is a block
/// map.
SourceEdit _removeFromBlockMap(
    YamlEditor yamlEdit, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  final keySpan = keyNode.span;
  var end = getContentSensitiveEnd(valueNode);
  final yaml = yamlEdit.toString();
  final lineEnding = getLineEnding(yaml);

  if (map.length == 1) {
    final start = map.span.start.offset;
    final nextNewLine = yaml.indexOf(lineEnding, end);
    if (nextNewLine != -1) {
      // Remove everything up to the next newline, this strips comments that
      // follows on the same line as the value we're removing.
      // It also ensures we consume colon when [valueNode.value] is `null`
      // because there is no value (e.g. `key: \n`). Because [valueNode.span] in
      // such cases point to the colon `:`.
      end = nextNewLine;
    } else {
      // Remove everything until the end of the document, if there is no newline
      end = yaml.length;
    }
    return SourceEdit(start, end - start, '{}');
  }

  var start = keySpan.start.offset;

  /// Adjust the end to clear the new line after the end too.
  ///
  /// We do this because we suspect that our users will want the inline
  /// comments to disappear too.
  final nextNewLine = yaml.indexOf(lineEnding, end);
  if (nextNewLine != -1) {
    end = nextNewLine + lineEnding.length;
  } else {
    // Remove everything until the end of the document, if there is no newline
    end = yaml.length;
  }

  final nextNode = getNextKeyNode(map, keyNode);

  if (start > 0) {
    final lastHyphen = yaml.lastIndexOf('-', start - 1);
    final lastNewLine = yaml.lastIndexOf(lineEnding, start - 1);
    if (lastHyphen > lastNewLine) {
      start = lastHyphen + 2;

      /// If there is a `-` before the node, and the end is on the same line
      /// as the next node, we need to add the necessary offset to the end to
      /// make sure the next node has the correct indentation.
      if (nextNode != null &&
          nextNode.span.start.offset - end <= nextNode.span.start.column) {
        end += nextNode.span.start.column;
      }
    } else if (lastNewLine > lastHyphen) {
      start = lastNewLine + lineEnding.length;
    }
  }

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yamlEdit] to achieve the effect of
/// removing the [keyNode] from the map, bearing in mind that this is a flow
/// map.
SourceEdit _removeFromFlowMap(
    YamlEditor yamlEdit, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  var start = keyNode.span.start.offset;
  var end = valueNode.span.end.offset;
  final yaml = yamlEdit.toString();

  if (deepEquals(keyNode, map.keys.first)) {
    start = yaml.lastIndexOf('{', start - 1) + 1;

    if (deepEquals(keyNode, map.keys.last)) {
      end = yaml.indexOf('}', end);
    } else {
      end = yaml.indexOf(',', end) + 1;
    }
  } else {
    start = yaml.lastIndexOf(',', start - 1);
  }

  return SourceEdit(start, end - start, '');
}
