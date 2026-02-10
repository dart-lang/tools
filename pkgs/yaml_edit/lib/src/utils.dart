// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'editor.dart';
import 'source_edit.dart';
import 'wrap.dart';

/// Invoke [fn] while setting [yamlWarningCallback] to [warn], and restore
/// [YamlWarningCallback] after [fn] returns.
///
/// Defaults to a [warn] function that ignores all warnings.
T withYamlWarningCallback<T>(
  T Function() fn, {
  YamlWarningCallback warn = _ignoreWarning,
}) {
  final original = yamlWarningCallback;
  try {
    yamlWarningCallback = warn;
    return fn();
  } finally {
    yamlWarningCallback = original;
  }
}

void _ignoreWarning(String warning, [SourceSpan? span]) {/* ignore warning */}

/// Determines if [string] is dangerous by checking if parsing the plain string
/// can return a result different from [string].
///
/// This function is also capable of detecting if non-printable characters are
/// in [string].
bool isDangerousString(String string) {
  try {
    final node = withYamlWarningCallback(() => loadYamlNode(string));
    if (node.value != string) {
      return true;
    }

    // [string] should also not contain the `[`, `]`, `,`, `{` and `}` indicator
    // characters.
    return string.contains(RegExp(r'\{|\[|\]|\}|,'));
  } catch (e) {
    /// This catch statement catches [ArgumentError] in `loadYamlNode` when
    /// a string can be interpreted as a URI tag, but catches for other
    /// [YamlException]s
    return true;
  }
}

/// Asserts that [value] is a valid scalar according to YAML.
///
/// A valid scalar is a number, String, boolean, or null.
void assertValidScalar(Object? value) {
  if (value is num || value is String || value is bool || value == null) {
    return;
  }

  throw ArgumentError.value(value, 'value', 'Not a valid scalar type!');
}

/// Checks if [node] is a [YamlNode] with block styling.
///
/// [ScalarStyle.ANY] and [CollectionStyle.ANY] are considered to be block
/// styling by default for maximum flexibility.
bool isBlockNode(YamlNode node) {
  if (node is YamlScalar) {
    if (node.style == ScalarStyle.LITERAL ||
        node.style == ScalarStyle.FOLDED ||
        node.style == ScalarStyle.ANY) {
      return true;
    }
  }

  if (node is YamlList &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) {
    return true;
  }
  if (node is YamlMap &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) {
    return true;
  }

  return false;
}

/// Returns the content sensitive ending offset of [yamlNode] (i.e. where the
/// last meaningful content happens)
int getContentSensitiveEnd(YamlNode yamlNode) {
  if (yamlNode is YamlList) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.last);
    }
  } else if (yamlNode is YamlMap) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.values.last);
    }
  }

  return yamlNode.span.end.offset;
}

/// Checks if the item is a Map or a List
bool isCollection(Object item) => item is Map || item is List;

/// Checks if [index] is [int], >=0, < [length]
bool isValidIndex(Object? index, int length) {
  return index is int && index >= 0 && index < length;
}

/// Checks if the item is empty, if it is a List or a Map.
///
/// Returns `false` if [item] is not a List or Map.
bool isEmpty(Object item) {
  if (item is Map) return item.isEmpty;
  if (item is List) return item.isEmpty;

  return false;
}

/// Creates a [SourceSpan] from [sourceUrl] with no meaningful location
/// information.
///
/// Mainly used with [wrapAsYamlNode] to allow for a reasonable
/// implementation of [SourceSpan.message].
SourceSpan shellSpan(Object? sourceUrl) {
  final shellSourceLocation = SourceLocation(0, sourceUrl: sourceUrl);
  return SourceSpanBase(shellSourceLocation, shellSourceLocation, '');
}

/// Returns if [value] is a [YamlList] or [YamlMap] with [CollectionStyle.FLOW].
bool isFlowYamlCollectionNode(Object value) =>
    value is YamlNode && value.collectionStyle == CollectionStyle.FLOW;

/// Determines the index where [newKey] will be inserted if the keys in [map]
/// are in alphabetical order when converted to strings.
///
/// Returns the length of [map] if the keys in [map] are not in alphabetical
/// order.
int getMapInsertionIndex(YamlMap map, Object newKey) {
  final keys = map.nodes.keys.map((k) => k.toString()).toList();

  // Detect if the keys are not already sorted, append new entry to the end
  for (var i = 1; i < keys.length; i++) {
    if (keys[i].compareTo(keys[i - 1]) < 0) {
      return map.length;
    }
  }

  final insertionIndex =
      keys.indexWhere((key) => key.compareTo(newKey as String) > 0);

  if (insertionIndex != -1) return insertionIndex;

  return map.length;
}

/// Returns the detected indentation step used in [editor], or defaults to a
/// value of `2` if no indentation step can be detected.
///
/// Indentation step is determined by the difference in indentation of the
/// first block-styled yaml collection in the second level as compared to the
/// top-level elements. In the case where there are multiple possible
/// candidates, we choose the candidate closest to the start of [editor].
int getIndentation(YamlEditor editor) {
  final node = editor.parseAt([]);
  Iterable<YamlNode>? children;
  var indentation = 2;

  if (node is YamlMap && node.style == CollectionStyle.BLOCK) {
    children = node.nodes.values;
  } else if (node is YamlList && node.style == CollectionStyle.BLOCK) {
    children = node.nodes;
  }

  if (children != null) {
    for (final child in children) {
      var indent = 0;
      if (child is YamlList) {
        indent = getListIndentation(editor.toString(), child);
      } else if (child is YamlMap) {
        indent = getMapIndentation(editor.toString(), child);
      }

      if (indent != 0) indentation = indent;
    }
  }
  return indentation;
}

/// Gets the indentation level of [list]. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
///
/// Throws [UnsupportedError] if an empty block map is passed in.
int getListIndentation(String yaml, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (list.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  final lastHyphen = yaml.lastIndexOf('-', lastSpanOffset - 1);

  if (lastHyphen == 0) return lastHyphen;

  // Look for '\n' that's before hyphen
  final lastNewLine = yaml.lastIndexOf('\n', lastHyphen - 1);

  return lastHyphen - lastNewLine - 1;
}

/// Gets the indentation level of [map]. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (map.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block map');
  }

  /// Use the number of spaces between the last key and the newline as
  /// indentation.
  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  final lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  final lastQuestionMark = yaml.lastIndexOf('?', lastSpanOffset);

  if (lastQuestionMark == -1) {
    if (lastNewLine == -1) return lastSpanOffset;
    return lastSpanOffset - lastNewLine - 1;
  }

  /// If there is a question mark, it might be a complex key. Check if it
  /// is on the same line as the key node to verify.
  if (lastNewLine == -1) return lastQuestionMark;
  if (lastQuestionMark > lastNewLine) {
    return lastQuestionMark - lastNewLine - 1;
  }

  return lastSpanOffset - lastNewLine - 1;
}

/// Returns the detected line ending used in [yaml], more specifically, whether
/// [yaml] appears to use Windows `\r\n` or Unix `\n` line endings.
///
/// The heuristic used is to count all `\n` in the text and if strictly more
/// than half of them are preceded by `\r` we report that windows line endings
/// are used.
String getLineEnding(String yaml) {
  var index = -1;
  var unixNewlines = 0;
  var windowsNewlines = 0;
  while ((index = yaml.indexOf('\n', index + 1)) != -1) {
    if (index != 0 && yaml[index - 1] == '\r') {
      windowsNewlines++;
    } else {
      unixNewlines++;
    }
  }

  return windowsNewlines > unixNewlines ? '\r\n' : '\n';
}

final _nonSpaceMatch = RegExp(r'[^ \t]');

/// Skip empty lines and returns the offset of the last possible line ending
/// only if the [offset] is a valid offset within the [yaml] string that
/// points to first line ending.
///
/// The [blockIndent] is used to truncate any comments more indented than the
/// parent collection that may affect other block entries within the collection
/// that may have block scalars.
int indexOfLastLineEnding(
  String yaml, {
  required int offset,
  required int blockIndent,
}) {
  if (yaml.isEmpty || offset == -1) return yaml.length;

  final lastOffset = yaml.length - 1;
  var currentOffset = min(offset, lastOffset);

  // Unsafe. Cannot start our scanner state machine in an unguarded state.
  if (yaml[currentOffset] != '\r' && yaml[currentOffset] != '\n') {
    return currentOffset;
  }

  var lineEndingIndex = currentOffset;

  // Skip empty lines and any comments indented more than the block entry. Such
  // comments are hazardous to block scalars.
  scanner:
  while (currentOffset <= lastOffset) {
    switch (yaml[currentOffset]) {
      case '\r':
        {
          // Skip carriage return if possible. No use to us if we have a line
          // feed after.
          if (currentOffset < lastOffset && yaml[currentOffset + 1] == '\n') {
            ++currentOffset;
          }

          continue indentChecker;
        }

      indentChecker:
      case '\n':
        {
          lineEndingIndex = currentOffset;
          ++currentOffset;

          if (currentOffset >= lastOffset) {
            lineEndingIndex = lastOffset;
            break scanner;
          }

          final offsetAfterIndent = yaml.indexOf(RegExp('[^ ]'), currentOffset);

          // No more characters!
          if (offsetAfterIndent == -1) {
            lineEndingIndex = lastOffset;
            break scanner;
          }

          final indent = offsetAfterIndent - currentOffset;
          currentOffset = offsetAfterIndent;
          final charAfterIndent = yaml[currentOffset];

          if (charAfterIndent case '\r' || '\n') {
            continue scanner;
          } else if (indent > blockIndent) {
            // If more indented than the entry, always attempt to truncate the
            // comment or skip it as an empty line.
            if (charAfterIndent == '\t') {
              continue skipIfEmpty;
            } else if (charAfterIndent == '#') {
              continue truncateComment;
            }
          }

          break scanner;
        }

      // Guarded by indentChecker. Force tabs to be associated with empty lines
      // if seen past the indent.
      skipIfEmpty:
      case '\t':
        {
          final nonSpace = yaml.indexOf(_nonSpaceMatch, currentOffset);

          if (nonSpace == -1) {
            lineEndingIndex = lastOffset;
          } else if (yaml[nonSpace] case '\r' || '\n') {
            currentOffset = nonSpace;
            continue scanner;
          }

          break scanner;
        }

      // Guarded by indentChecker. This ensures we only skip comments indented
      // more than the entry itself.
      truncateComment:
      case '#':
        {
          final lineFeedOffset = yaml.indexOf('\n', currentOffset);

          if (lineFeedOffset == -1) {
            lineEndingIndex = lastOffset;
            break scanner;
          }

          currentOffset = lineFeedOffset;
          continue indentChecker;
        }

      default:
        break scanner;
    }
  }

  return lineEndingIndex;
}

/// Backtracks from the [start] offset and looks for the nearest character
/// that is not a separation space (tab/space) that can be used to declare a
/// nested compact block map
///
/// ```yaml
/// # In a block list
/// - key: value
///   next: value
///
/// ---
/// # In an explicit key and its value
///
/// ? key: value
///   next: value
/// : key: value
///   next: value
/// ```
///
/// If a line feed `\n` is encountered first then `compactCharOffset` defaults
/// to -1. Otherwise, only returns a non-negative `compactCharOffset` if
/// `?`, `-` or `:` were seen.
({int compactCharOffset, int lineEndingIndex}) indexOfCompactChar(
  String yaml,
  int start,
) {
  /// Look back past the indent/separation space.
  final startOffset = max(
    0,
    yaml.lastIndexOf(_nonSpaceMatch, max(0, start - 1)),
  );

  return switch (yaml[startOffset]) {
    '\r' || '\n' => (compactCharOffset: -1, lineEndingIndex: startOffset),

    /// Block sequences and explicit keys/values can be used to declare block
    /// maps/sequences in a compact-inline notation.
    ///
    /// - a: b
    ///   c: d
    ///
    /// - - a
    ///   - b
    ///
    /// OR as an explicit key with its explicit value
    ///
    /// ? a: b
    ///   c: d
    /// : e: f
    ///   g: h
    ///
    /// ? - sequence
    ///   - as key
    /// : - sequence
    ///   - as value
    ///
    /// See "Example 8.19 Compact Block Mappings" at
    /// https://yaml.org/spec/1.2.2/#822-block-mappings
    '-' || '?' || ':' => (compactCharOffset: startOffset, lineEndingIndex: -1),
    _ => (compactCharOffset: -1, lineEndingIndex: -1)
  };
}

typedef NextBlockNodeInfo = ({int nearestLineEnding, int nextNodeColStart});
typedef BlockNodeOffset = ({int start, int end});

/// Removes a block entry and its line ending from a [blockCollection] using the
/// [nodeToRemoveOffset] provided. Any trailing comments are also removed.
///
/// If [blockCollection] is a [YamlMap], the chunk removed corresponds to the
/// key-value pair represented by the offset. If [blockCollection] is a
/// [YamlList], the chunk represents a single element within the list.
///
/// [nextBlockNodeInfo] is only called if the [blockCollection] has at least
/// 2 entries and the entry being removed is not the last entry in the
/// collection.
SourceEdit removeBlockCollectionEntry(
  String yaml, {
  required YamlNode blockCollection,
  required int collectionIndent,
  required bool isFirstEntry,
  required bool isSingleEntry,
  required bool isLastEntry,
  required BlockNodeOffset nodeToRemoveOffset,
  required String lineEnding,
  required NextBlockNodeInfo Function() nextBlockNodeInfo,
}) {
  final isBlockList = blockCollection is YamlList;

  assert(
    isBlockList || blockCollection is YamlMap,
    'Expected a block map/list',
  );

  var makeNextNodeCompact = false;
  var (:start, :end) = nodeToRemoveOffset;

  // Skip empty lines to the last line break
  end = indexOfLastLineEnding(
    yaml,
    offset: yaml.indexOf('\n', end - 1),
    blockIndent: collectionIndent,
  );

  end = min(++end, yaml.length); // Mark it for removal

  if (isSingleEntry) {
    // Preserve when sandwiched or if an EOF line ending was present.
    if (end < yaml.length || yaml.endsWith('\n')) {
      end -= lineEnding == '\r\n' ? 2 : 1;
    }

    return SourceEdit(start, end - start, isBlockList ? '[]' : '{}');
  } else if (isLastEntry) {
    start = yaml.lastIndexOf('\n', start) + 1;
    end = max(yaml.lastIndexOf('\n', blockCollection.span.end.offset) + 1, end);
    return SourceEdit(start, end - start, '');
  }

  if (start != 0) {
    // Try making it compact in case the collection's parent is a:
    //    - block sequence
    //    - explicit key
    //    - explicit key's explicit value.
    if (isFirstEntry) {
      final (:compactCharOffset, :lineEndingIndex) = indexOfCompactChar(
        yaml,
        start,
      );

      if (compactCharOffset != -1) {
        start = compactCharOffset + 2; // Skip separation space.
        makeNextNodeCompact = true;
      } else {
        start = lineEndingIndex + 1;
      }
    } else {
      // If not possible, just consume this node's indent. This prevents this
      // node from interfering with the next node.
      start = yaml.lastIndexOf('\n', start) + 1;
    }
  }

  final (:nearestLineEnding, :nextNodeColStart) = nextBlockNodeInfo();
  final trueEndOffset = end - 1;

  // Make compact only if we are pointing to same line break from different
  // node extremes. This can only be true if we are removing the first
  // entry.
  //
  // ** For block lists **
  //
  // [*] Before:
  //
  // - - value
  //   - next
  //
  // [*] After:
  //
  // - - next
  //
  // ** For block maps **
  //
  // [*] Before:
  //
  // - key: value
  //   next: value
  //
  // [*] After:
  //
  // - next: value
  end = makeNextNodeCompact && nearestLineEnding == trueEndOffset
      ? end + nextNodeColStart
      : end;

  return SourceEdit(start, end - start, '');
}

extension YamlNodeExtension on YamlNode {
  /// Returns the [CollectionStyle] of `this` if `this` is [YamlMap] or
  /// [YamlList].
  ///
  /// Otherwise, returns `null`.
  CollectionStyle? get collectionStyle {
    final me = this;
    if (me is YamlMap) return me.style;
    if (me is YamlList) return me.style;
    return null;
  }
}
