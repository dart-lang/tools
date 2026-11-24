// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Read-only text, layout, alias, and navigation helpers on [CstDocument].
///
/// Shared by CST slot mutations and debug-mode edit invariant checks.
library;

import 'package:yaml/yaml.dart';

import 'cst.dart';
import 'equality.dart';

/// Text and whitespace helpers on [CstDocument] used by slot mutations and
/// debug-mode invariant checks.
extension CstDocumentTextHelpers on CstDocument {
  /// Returns the byte length of the line break starting at [offset]
  /// (`2` for `\r\n`, `1` for `\n` or `\r`, and `0` otherwise).
  int lineBreakLengthAt(int offset) {
    if (offset < 0 || offset >= source.length) return 0;
    final char = source.codeUnitAt(offset);
    if (char == 0x0A) return 1;
    if (char == 0x0D) {
      return (offset + 1 < source.length &&
              source.codeUnitAt(offset + 1) == 0x0A)
          ? 2
          : 1;
    }
    return 0;
  }

  /// Whether a line break starts at [offset].
  bool hasLineBreakAt(int offset) => lineBreakLengthAt(offset) > 0;

  /// Returns the byte length of the line break immediately preceding [offset]
  /// (`2` for `\r\n`, `1` for `\n` or `\r`, and `0` otherwise).
  int lineBreakLengthBefore(int offset) {
    if (offset <= 0 || offset > source.length) return 0;
    final prev = source.codeUnitAt(offset - 1);
    if (prev == 0x0A) {
      return (offset >= 2 && source.codeUnitAt(offset - 2) == 0x0D) ? 2 : 1;
    }
    if (prev == 0x0D) return 1;
    return 0;
  }

  /// Whether a line break ends immediately before [offset].
  bool hasLineBreakBefore(int offset) => lineBreakLengthBefore(offset) > 0;

  /// Whether `[start, end)` contains any line break.
  bool hasLineBreakInRange(int start, int end) {
    if (start >= end) return false;
    return lineStartOf(start) != lineStartOf(end - 1) ||
        hasLineBreakAt(end - 1);
  }

  /// Whether the character immediately before [offset] is a space or tab.
  bool hasWhitespaceBefore(int offset) {
    if (offset <= 0 || offset > source.length) return false;
    final char = source.codeUnitAt(offset - 1);
    return char == 0x20 || char == 0x09;
  }

  /// Returns [end] trimmed backward over trailing spaces, tabs, and line
  /// breaks (never going before [start]).
  ///
  /// `package:yaml` extends plain-scalar spans inside flow collections through
  /// trailing whitespace and line breaks up to the closing delimiter; trimming
  /// prevents edits from swallowing the line break before `]` or `}`.
  int trimmedEnd(int start, int end) {
    var cursor = end;
    while (cursor > start) {
      final char = source.codeUnitAt(cursor - 1);
      if (char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D) {
        cursor--;
      } else {
        break;
      }
    }
    return cursor;
  }

  /// Whether every character in `[start, end)` is a space or tab.
  bool isWhitespaceRange(int start, int end) {
    for (var i = start; i < end; i++) {
      final char = source.codeUnitAt(i);
      if (char != 0x20 && char != 0x09) return false;
    }
    return true;
  }

  /// Whether `[start, end)` contains a horizontal tab (`\t`).
  bool hasTabInRange(int start, int end) {
    for (var i = start; i < end; i++) {
      if (source.codeUnitAt(i) == 0x09) return true;
    }
    return false;
  }

  /// Extends [startOffset] past any trailing blank lines and comments indented
  /// strictly more than [collectionIndent].
  ///
  /// When [preserveTrailingBlankLines] is `true`, trailing blank lines are only
  /// consumed if followed by an over-indented comment, preserving
  /// section-separating blank lines that belong to an enclosing collection.
  int extendPastIndentedCommentsAndBlankLines(
    int startOffset,
    int collectionIndent, {
    bool preserveTrailingBlankLines = false,
  }) {
    var endOffset = startOffset;
    var probe = endOffset;

    while (probe < source.length) {
      final lineStart = lineStartOf(probe);
      if (probe != lineStart) break;

      final lineContentEnd = lineContentEndOf(probe);
      final lineBreakEnd = lineBreakEndOf(probe);

      final comment = commentInRange(lineStart, lineContentEnd);
      if (comment != null) {
        final column = comment.span.start.offset - lineStart;
        if (isWhitespaceRange(lineStart, comment.span.start.offset) &&
            column > collectionIndent) {
          endOffset = lineBreakEnd;
          probe = lineBreakEnd;
          continue;
        }
        break;
      }

      if (isWhitespaceRange(lineStart, lineContentEnd)) {
        if (!preserveTrailingBlankLines) {
          endOffset = lineBreakEnd;
        }
        probe = lineBreakEnd;
        continue;
      }

      break;
    }

    return endOffset;
  }
}

/// Collects all [YamlNode] values referenced by any [CstAlias] in [document].
///
/// Walks the CST iteratively so deeply nested documents do not overflow the
/// call stack.
Set<YamlNode> collectAliasedValues(CstDocument document) {
  final root = document.root;
  if (root == null) return const {};
  final result = <YamlNode>{};
  final stack = <CstNode>[root];
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    switch (node) {
      case CstAlias():
        result.add(node.value);
      case CstBlockSeq():
        for (final entry in node.entries) {
          stack.add(entry.value);
        }
      case CstBlockMap():
        for (final entry in node.entries) {
          stack.add(entry.key);
          stack.add(entry.value);
        }
      case CstFlowCollection():
        for (final entry in node.entries) {
          if (entry.key case final key?) stack.add(key);
          stack.add(entry.value);
        }
      case CstFlowPair():
        stack.add(node.key);
        stack.add(node.pairValue);
      case CstScalar() || CstEmpty():
        break;
    }
  }
  return result;
}

/// The layout conventions to follow when writing new content into a document.
///
/// These are inferred from the document itself so that added content matches
/// what is already there.
final class LayoutStyle {
  /// How many columns each level of block nesting is indented by.
  final int indentStep;

  /// The line terminator the document uses.
  final String lineEnding;

  LayoutStyle({required this.indentStep, required this.lineEnding});

  /// Infers the conventions used by [document].
  ///
  /// The indentation step is taken from the first block collection nested
  /// directly inside the root, and defaults to two columns when the document
  /// has no nesting to learn from.
  factory LayoutStyle.of(CstDocument document) {
    var indentStep = 2;
    final root = document.root;
    final rootIndent = switch (root) {
      CstBlockSeq() => document.columnOf(root.entries.first.dashStart),
      CstBlockMap() => document.columnOf(root.entries.first.keyStart),
      _ => 0,
    };
    final children = switch (root) {
      CstBlockSeq() => [for (final entry in root.entries) entry.value],
      CstBlockMap() => [for (final entry in root.entries) entry.value],
      _ => const <CstNode>[],
    };
    for (final child in children) {
      final childIndent = switch (child) {
        CstBlockSeq() => document.columnOf(child.entries.first.dashStart),
        CstBlockMap() => document.columnOf(child.entries.first.keyStart),
        _ => 0,
      };
      if (childIndent > rootIndent) {
        indentStep = childIndent - rootIndent;
        break;
      }
    }
    return LayoutStyle(
      indentStep: indentStep,
      lineEnding: document.lineEnding,
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

/// The entries of [node] if it is a sequence, and `null` otherwise.
List<CstNode>? sequenceItems(CstNode node) => switch (node) {
      CstBlockSeq() => [for (final entry in node.entries) entry.value],
      CstFlowSeq() => [for (final entry in node.entries) entry.value],
      _ => null,
    };

/// The key/value pairs of [node] if it is a mapping, and `null` otherwise.
List<({CstNode key, CstNode value})>? mappingPairs(CstNode node) =>
    switch (node) {
      CstBlockMap() => [
          for (final entry in node.entries) (key: entry.key, value: entry.value)
        ],
      CstFlowMap() => [
          for (final entry in node.entries)
            (key: entry.key!, value: entry.value)
        ],
      CstFlowPair() => [(key: node.key, value: node.pairValue)],
      _ => null,
    };

/// Locates the node at [path] within [document].
///
/// Returns `null` if nothing lives at [path], or if the document is empty and
/// [path] is not.
CstNode? findNode(CstDocument document, Iterable<Object?> path) {
  var current = document.root;
  for (final step in path) {
    if (current == null) return null;
    final items = sequenceItems(current);
    if (items != null) {
      if (step is! int || step < 0 || step >= items.length) return null;
      current = items[step];
      continue;
    }
    final pairs = mappingPairs(current);
    if (pairs == null) return null;
    final match =
        pairs.where((pair) => deepEquals(pair.key.value, step)).firstOrNull;
    if (match == null) return null;
    current = match.value;
  }
  return current;
}

/// The index of the entry of the mapping [node] whose key equals [key].
///
/// Returns `null` when there is no such entry.
int? findEntryIndex(CstNode node, Object? key) {
  final pairs = mappingPairs(node);
  if (pairs == null) return null;
  for (var index = 0; index < pairs.length; index++) {
    if (deepEquals(pairs[index].key.value, key)) return index;
  }
  return null;
}
