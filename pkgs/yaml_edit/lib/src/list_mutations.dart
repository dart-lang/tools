// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

import 'editor.dart';
import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';
import 'wrap.dart';

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of setting the element at [index] to [newValue] when
/// re-parsed.
SourceEdit updateInList(
    YamlEditor yamlEdit, YamlList list, int index, YamlNode newValue) {
  RangeError.checkValueInInterval(index, 0, list.length - 1);

  final currValue = list.nodes[index];
  var offset = currValue.span.start.offset;
  final yaml = yamlEdit.toString();
  String valueString;

  /// We do not use [_formatNewBlock] since we want to only replace the contents
  /// of this node while preserving comments/whitespace, while [_formatNewBlock]
  /// produces a string representation of a new node.
  if (list.style == CollectionStyle.BLOCK) {
    final listIndentation = getListIndentation(yaml, list);
    final indentation = listIndentation + getIndentation(yamlEdit);
    final lineEnding = getLineEnding(yaml);
    valueString =
        yamlEncodeBlock(wrapAsYamlNode(newValue), indentation, lineEnding);

    /// We prefer the compact nested notation for collections.
    ///
    /// By virtue of [yamlEncodeBlockString], collections automatically
    /// have the necessary line endings.
    if ((newValue is List && (newValue as List).isNotEmpty) ||
        (newValue is Map && (newValue as Map).isNotEmpty)) {
      valueString = valueString.substring(indentation);
    } else if (currValue.collectionStyle == CollectionStyle.BLOCK) {
      valueString += lineEnding;
    }

    var end = getContentSensitiveEnd(currValue);
    if (end <= offset) {
      offset++;
      end = offset;
      valueString = ' $valueString';
    }

    return SourceEdit(offset, end - offset, valueString);
  } else {
    valueString = yamlEncodeFlow(newValue);
    return SourceEdit(offset, currValue.span.length, valueString);
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of appending [item] to the list.
SourceEdit appendIntoList(YamlEditor yamlEdit, YamlList list, YamlNode item) {
  if (list.style == CollectionStyle.FLOW) {
    return _appendToFlowList(yamlEdit, list, item);
  } else {
    return _appendToBlockList(yamlEdit, list, item);
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of inserting [item] to the list at [index].
SourceEdit insertInList(
    YamlEditor yamlEdit, YamlList list, int index, YamlNode item) {
  RangeError.checkValueInInterval(index, 0, list.length);

  /// We call the append method if the user wants to append it to the end of the
  /// list because appending requires different techniques.
  if (index == list.length) {
    return appendIntoList(yamlEdit, list, item);
  } else {
    if (list.style == CollectionStyle.FLOW) {
      return _insertInFlowList(yamlEdit, list, index, item);
    } else {
      return _insertInBlockList(yamlEdit, list, index, item);
    }
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of removing the element at [index] when re-parsed.
SourceEdit removeInList(YamlEditor yamlEdit, YamlList list, int index) {
  final nodeToRemove = list.nodes[index];

  if (list.style == CollectionStyle.FLOW) {
    return _removeFromFlowList(yamlEdit, list, nodeToRemove, index);
  } else {
    return _removeFromBlockList(yamlEdit, list, nodeToRemove, index);
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of addition [item] into [list], noting that this is a
/// flow list.
SourceEdit _appendToFlowList(
    YamlEditor yamlEdit, YamlList list, YamlNode item) {
  final valueString = _formatNewFlow(list, item, true);
  return SourceEdit(list.span.end.offset - 1, 0, valueString);
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of addition [item] into [list], noting that this is a
/// block list.
SourceEdit _appendToBlockList(
    YamlEditor yamlEdit, YamlList list, YamlNode item) {
  var (indentSize, valueToIndent) = _formatNewBlock(yamlEdit, list, item);
  var formattedValue = '${' ' * indentSize}$valueToIndent';

  final yaml = yamlEdit.toString();
  var offset = list.span.end.offset;

  // Adjusts offset to after the trailing newline of the last entry, if it
  // exists
  if (list.isNotEmpty) {
    final lastValueSpanEnd = list.nodes.last.span.end.offset;
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd - 1);
    if (nextNewLineIndex == -1) {
      formattedValue = getLineEnding(yaml) + formattedValue;
    } else {
      offset = nextNewLineIndex + 1;
    }
  }

  return SourceEdit(offset, 0, formattedValue);
}

/// Formats [item] into a new node for block lists.
(int indentSize, String valueStringToIndent) _formatNewBlock(
    YamlEditor yamlEdit, YamlList list, YamlNode item) {
  final yaml = yamlEdit.toString();
  final listIndentation = getListIndentation(yaml, list);
  final newIndentation = listIndentation + getIndentation(yamlEdit);
  final lineEnding = getLineEnding(yaml);

  var valueString = yamlEncodeBlock(item, newIndentation, lineEnding);
  if (isCollection(item) && !isFlowYamlCollectionNode(item) && !isEmpty(item)) {
    valueString = valueString.substring(newIndentation);
  }

  return (listIndentation, '- $valueString$lineEnding');
}

/// Formats [item] into a new node for flow lists.
String _formatNewFlow(YamlList list, YamlNode item, [bool isLast = false]) {
  var valueString = yamlEncodeFlow(item);
  if (list.isNotEmpty) {
    if (isLast) {
      valueString = ', $valueString';
    } else {
      valueString += ', ';
    }
  }

  return valueString;
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of inserting [item] into [list] at [index], noting that
/// this is a block list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _insertInBlockList(
    YamlEditor yamlEdit, YamlList list, int index, YamlNode item) {
  RangeError.checkValueInInterval(index, 0, list.length);

  if (index == list.length) return _appendToBlockList(yamlEdit, list, item);

  var (indentSize, formattedValue) = _formatNewBlock(yamlEdit, list, item);

  final currNode = list.nodes[index];
  final currNodeStart = currNode.span.start.offset;
  final yaml = yamlEdit.toString();

  final currSequenceOffset = yaml.lastIndexOf('-', currNodeStart - 1);

  final (isNested, offset) = _isNestedInBlockList(currSequenceOffset, yaml);

  /// We have to get rid of the left indentation applied by default
  if (isNested && index == 0) {
    /// The [insertionIndex] will be equal to the start of
    /// [currentSequenceOffset] of the element we are inserting before in most
    /// cases.
    ///
    /// Example:
    ///
    ///   - - value
    ///     ^ Inserting before this and we get rid of indent
    ///
    /// If not, we need to account for the space between them that is not an
    /// indent.
    ///
    /// Example:
    ///
    ///   -   - value
    ///       ^ Inserting before this and we get rid of indent. But also account
    ///         for space in between
    final leftPad = currSequenceOffset - offset;
    final padding = ' ' * leftPad;

    final indent = ' ' * (indentSize - leftPad);

    // Give the indent to the first element
    formattedValue = '$padding${formattedValue.trimLeft()}$indent';
  } else {
    final indent = ' ' * indentSize; // Calculate indent normally
    formattedValue = '$indent$formattedValue';
  }

  return SourceEdit(offset, 0, formattedValue);
}

/// Determines if the list containing an element is nested within another list.
/// The [currentSequenceOffset] indicates the index of the element's `-` and
/// [yaml] represents the entire yaml document.
///
/// ```yaml
/// # Returns true
/// - - value
///
/// # Returns true
/// -       - value
///
/// # Returns false
/// key:
///   - value
///
/// # Returns false. Even though nested, a "\n" precedes the previous "-"
/// -
///   - value
/// ```
(bool isNested, int offset) _isNestedInBlockList(
    int currentSequenceOffset, String yaml) {
  final startIndex = currentSequenceOffset - 1;

  /// Indicates the element we are inserting before is at index `0` of the list
  /// at the root of the yaml
  ///
  /// Example:
  ///
  /// - foo
  /// ^ Inserting before this
  if (startIndex < 0) return (false, 0);

  final newLineStart = yaml.lastIndexOf('\n', startIndex);
  final seqStart = yaml.lastIndexOf('-', startIndex);

  /// Indicates that a `\n` is closer to the last `-`. Meaning this list is not
  /// nested.
  ///
  /// Example:
  ///
  ///   key:
  ///     - value
  ///     ^ Inserting before this and we need to keep the indent.
  ///
  /// Also this list may be nested but the nested list starts its indent after
  /// a new line.
  ///
  /// Example:
  ///
  ///   -
  ///     - value
  ///     ^ Inserting before this and we need to keep the indent.
  if (newLineStart >= seqStart) {
    return (false, newLineStart + 1);
  }

  return (true, seqStart + 2); // Inclusive of space
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of inserting [item] into [list] at [index], noting that
/// this is a flow list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _insertInFlowList(
    YamlEditor yamlEdit, YamlList list, int index, YamlNode item) {
  RangeError.checkValueInInterval(index, 0, list.length);

  if (index == list.length) return _appendToFlowList(yamlEdit, list, item);

  final formattedValue = _formatNewFlow(list, item);

  final yaml = yamlEdit.toString();
  final currNode = list.nodes[index];
  final currNodeStart = currNode.span.start.offset;
  var start = yaml.lastIndexOf(RegExp(r',|\['), currNodeStart - 1) + 1;
  if (yaml[start] == ' ') start++;

  return SourceEdit(start, 0, formattedValue);
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of removing [nodeToRemove] from [list], noting that this
/// is a block list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _removeFromBlockList(
    YamlEditor yamlEdit, YamlList list, YamlNode nodeToRemove, int index) {
  RangeError.checkValueInInterval(index, 0, list.length - 1);

  var end = getContentSensitiveEnd(nodeToRemove);

  /// If we are removing the last element in a block list, convert it into a
  /// flow empty list.
  if (list.length == 1) {
    final start = list.span.start.offset;

    return SourceEdit(start, end - start, '[]');
  }

  final yaml = yamlEdit.toString();
  final span = nodeToRemove.span;

  /// Adjust the end to clear the new line after the end too.
  ///
  /// We do this because we suspect that our users will want the inline
  /// comments to disappear too.
  final nextNewLine = yaml.indexOf('\n', end);
  if (nextNewLine != -1) {
    end = nextNewLine + 1;
  }

  /// If the value is empty
  if (span.length == 0) {
    var start = span.start.offset;
    return SourceEdit(start, end - start, '');
  }

  /// -1 accounts for the fact that the content can start with a dash
  var start = yaml.lastIndexOf('-', span.start.offset - 1);

  /// Check if there is a `-` before the node
  if (start > 0) {
    final lastHyphen = yaml.lastIndexOf('-', start - 1);
    final lastNewLine = yaml.lastIndexOf('\n', start - 1);
    if (lastHyphen > lastNewLine) {
      start = lastHyphen + 2;

      /// If there is a `-` before the node, we need to check if we have
      /// to update the indentation of the next node.
      if (index < list.length - 1) {
        /// Since [end] is currently set to the next new line after the current
        /// node, check if we see a possible comment first, or a hyphen first.
        /// Note that no actual content can appear here.
        ///
        /// We check this way because the start of a span in a block list is
        /// the start of its value, and checking from the back leaves us
        /// easily confused if there are comments that have dashes in them.
        final nextHash = yaml.indexOf('#', end);
        final nextHyphen = yaml.indexOf('-', end);
        final nextNewLine = yaml.indexOf('\n', end);

        /// If [end] is on the same line as the hyphen of the next node
        if ((nextHash == -1 || nextHyphen < nextHash) &&
            nextHyphen < nextNewLine) {
          end = nextHyphen;
        }
      }
    } else if (lastNewLine > lastHyphen) {
      start = lastNewLine + 1;
    }
  }

  return SourceEdit(start, end - start, '');
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of removing [nodeToRemove] from [list], noting that this
/// is a flow list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _removeFromFlowList(
    YamlEditor yamlEdit, YamlList list, YamlNode nodeToRemove, int index) {
  RangeError.checkValueInInterval(index, 0, list.length - 1);

  final span = nodeToRemove.span;
  final yaml = yamlEdit.toString();
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = yaml.lastIndexOf('[', start - 1) + 1;
    if (index == list.length - 1) {
      end = yaml.indexOf(']', end);
    } else {
      end = yaml.indexOf(',', end) + 1;
    }
  } else {
    start = yaml.lastIndexOf(',', start - 1);
  }

  return SourceEdit(start, end - start, '');
}
