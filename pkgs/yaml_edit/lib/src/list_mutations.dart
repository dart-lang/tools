// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

import 'char_codes.dart';
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
  final trueSpan = yamlEdit.getTrueSpan(list, index);
  var offset = trueSpan.start.offset;
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

    var end = yamlEdit.getTrueContentSensitiveEnd(list, index);
    final anchorTag = yamlEdit.getAnchorTag(list, index);
    // Preserve any anchor definition on this element. For block collections
    // starting on a new line, place the anchor tag on the hyphen line before
    // the newline; otherwise format it inline.
    if (anchorTag != null) {
      if (valueString.startsWith(lineEnding)) {
        valueString = ' $anchorTag$valueString';
      } else {
        valueString = ' $anchorTag ${valueString.trimLeft()}';
      }
      if (offset > 0 && yaml[offset - 1] != ' ') {
        valueString = ' $valueString';
      }
    } else if (end <= offset) {
      offset++;
      end = offset;
      valueString = ' $valueString';
    }

    if (valueString.trimLeft().startsWith('|') ||
        valueString.trimLeft().startsWith('>')) {
      final (:replacement, :endOffset) = preserveTrailingCommentOnBlockScalar(
        oldNode: currValue,
        yaml: yaml,
        replacement: valueString,
        currentEndOffset: end,
        lineEnding: lineEnding,
        blockIndent: listIndentation,
      );
      valueString = replacement;
      end = endOffset;
    }

    return SourceEdit(offset, end - offset, valueString);
  } else {
    valueString = yamlEncodeFlow(newValue);
    final anchorTag = yamlEdit.getAnchorTag(list, index);
    if (anchorTag != null) {
      valueString = '$anchorTag $valueString';
    }
    return SourceEdit(offset, trueSpan.length, valueString);
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
  if (list.isEmpty) {
    final valueString = _formatNewFlow(list, item, true);
    return SourceEdit(list.span.end.offset - 1, 0, valueString);
  }

  final yaml = yamlEdit.toString();
  final lastNode = list.nodes.last;
  final closingOffset = list.span.end.offset - 1;
  final between = yaml.substring(lastNode.span.end.offset, closingOffset);
  final hasTrailing = betweenHasTrailingComma(between);

  final valueString = yamlEncodeFlow(item);
  String formattedValue;
  if (hasTrailing) {
    // If there is already a trailing comma in the flow list, do not prepend
    // another comma. If the flow list spans multiple lines with the closing
    // bracket on a new line, align the new entry with the previous elements.
    if (between.contains('\n')) {
      formattedValue = formatMultilineFlowTrailingEntry(
        closingOffset: closingOffset,
        lastEntryStartOffset: lastNode.span.start.offset,
        newEntry: valueString,
        yaml: yaml,
      );
    } else {
      var v = valueString;
      if (!RegExp(r'\s$').hasMatch(between)) {
        v = ' $v';
      }
      formattedValue = '$v,';
    }
  } else {
    formattedValue = _formatNewFlow(list, item, true);
  }

  return SourceEdit(closingOffset, 0, formattedValue);
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
    final lastValueSpanEnd =
        yamlEdit.getTrueContentSensitiveEnd(list, list.length - 1);
    var nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);
    if (nextNewLineIndex == -1) {
      formattedValue = getLineEnding(yaml) + formattedValue;
    } else {
      while (nextNewLineIndex + 1 < yaml.length) {
        final nextLineEnd = yaml.indexOf('\n', nextNewLineIndex + 1);
        final lineSlice = nextLineEnd == -1
            ? yaml.substring(nextNewLineIndex + 1)
            : yaml.substring(nextNewLineIndex + 1, nextLineEnd);
        final trimmed = lineSlice.trim();
        if (trimmed.isEmpty && nextLineEnd != -1) {
          nextNewLineIndex = nextLineEnd;
        } else if (trimmed.startsWith('#')) {
          final commentIndent = lineSlice.length - lineSlice.trimLeft().length;
          if (commentIndent >= indentSize) {
            nextNewLineIndex = nextLineEnd != -1 ? nextLineEnd : yaml.length;
          } else {
            break;
          }
        } else {
          break;
        }
      }
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

  final currSequenceOffset = list.dashSpan(index)?.start.offset ??
      yaml.lastIndexOf('-', currNodeStart - 1);

  final lineStart = currSequenceOffset > 0
      ? yaml.lastIndexOf('\n', currSequenceOffset - 1) + 1
      : 0;
  final linePrefix = yaml.substring(lineStart, currSequenceOffset);

  if (linePrefix.trim().isNotEmpty && index == 0) {
    final currentSequenceCol = currSequenceOffset - lineStart;
    formattedValue = '$formattedValue${' ' * currentSequenceCol}';
    return SourceEdit(currSequenceOffset, 0, formattedValue);
  }

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
  var start = findPreviousFlowDelimiter(
        yaml,
        currNodeStart - 1,
        delimiters: {YamlChar.comma, YamlChar.leftSquare},
      ) +
      1;
  if (start < yaml.length && yaml[start] == ' ') start++;

  return SourceEdit(start, 0, formattedValue);
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of removing [nodeToRemove] from [list], noting that this
/// is a block list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _removeFromBlockList(
    YamlEditor yamlEdit, YamlList list, YamlNode nodeToRemove, int index) {
  final listSize = list.length;
  RangeError.checkValueInInterval(index, 0, listSize - 1);

  final yaml = yamlEdit.toString();
  final span = yamlEdit.getTrueSpan(list, index);

  final isEmptySpan = span.length == 0; // Just the '-'
  final end = yamlEdit.getTrueContentSensitiveEnd(list, index);

  return removeBlockCollectionEntry(
    yaml,
    blockCollection: list,
    collectionIndent: getListIndentation(yaml, list),
    isFirstEntry: index == 0,
    isSingleEntry: listSize == 1,
    isLastEntry: index >= listSize - 1,
    nodeToRemoveOffset: (
      start: list.dashSpan(index)?.start.offset ??
          yaml.lastIndexOf(
            '-',
            isEmptySpan ? span.start.offset : span.start.offset - 1,
          ),
      end: isEmptySpan ? (list.dashSpan(index)?.end.offset ?? end + 1) : end,
    ),
    lineEnding: getLineEnding(yaml),
    nextBlockNodeInfo: () {
      final nextDash = list.dashSpan(index + 1);
      if (nextDash != null) {
        final hyphenOffset = nextDash.start.offset;
        final nearestLineEnding = yaml.lastIndexOf('\n', hyphenOffset);
        return (
          nearestLineEnding: nearestLineEnding,
          nextNodeColStart: nextDash.start.column,
        );
      }
      final nextNodeSpan = yamlEdit.getTrueSpan(list, index + 1);
      final offset = nextNodeSpan.start.offset;

      final hyphenOffset = yaml.lastIndexOf(
        '-',
        nextNodeSpan.length == 0 ? offset : offset - 1,
      );

      final nearestLineEnding = yaml.lastIndexOf('\n', hyphenOffset);

      return (
        nearestLineEnding: nearestLineEnding,
        nextNodeColStart: hyphenOffset - (nearestLineEnding + 1),
      );
    },
  );
}

/// Returns a [SourceEdit] describing the change to be made on [yamlEdit] to
/// achieve the effect of removing [nodeToRemove] from [list], noting that this
/// is a flow list.
///
/// [index] should be non-negative and less than or equal to `list.length`.
SourceEdit _removeFromFlowList(
    YamlEditor yamlEdit, YamlList list, YamlNode nodeToRemove, int index) {
  RangeError.checkValueInInterval(index, 0, list.length - 1);

  final span = yamlEdit.getTrueSpan(list, index);
  final yaml = yamlEdit.toString();
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = findPreviousFlowDelimiter(
          yaml,
          start - 1,
          delimiters: {YamlChar.leftSquare},
        ) +
        1;
    if (index == list.length - 1) {
      end = findNextFlowDelimiter(
        yaml,
        end,
        delimiters: {YamlChar.rightSquare},
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
