// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Computes [SourceEdit]s for mutating a [CstDocument].
///
/// Mutations operate directly on CST node and entry slot boundaries (such as
/// key, colon, and value offsets in mappings, or dash, comma, and delimiter
/// offsets in collections) while preserving surrounding comments and layout.
library;

import 'package:yaml/yaml.dart';

import 'cst.dart';
import 'equality.dart';
import 'errors.dart';
import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';
import 'wrap.dart';

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

// ---------------------------------------------------------------------------
// Encoding new content
// ---------------------------------------------------------------------------

/// A newly encoded value, together with how it must be joined to the syntax
/// that introduces it.
final class EncodedValue {
  /// The value's source text.
  ///
  /// When [ownLine] is true this begins with the value's own indentation.
  final String text;

  /// Whether the value must begin on a line of its own.
  ///
  /// Block collections must; everything else — scalars, including block
  /// scalars whose header stays on the introducing line, and flow collections —
  /// may follow the `-` or `:` directly.
  final bool ownLine;

  EncodedValue({required this.text, required this.ownLine});
}

/// Whether [value] will be written as a block collection occupying its own
/// lines.
///
/// Empty collections are the exception: there is no way to write an empty block
/// collection, so they come out as `[]` or `{}` and stay on one line.
bool _spansOwnLines(YamlNode value) {
  if (!isBlockNode(value)) return false;
  return switch (value) {
    YamlList() => value.isNotEmpty,
    YamlMap() => value.isNotEmpty,
    _ => false,
  };
}

/// Encodes [value] to be written as the content introduced by an indicator at
/// column [indicatorColumn].
///
/// The value is indented one [LayoutStyle.indentStep] past the indicator when
/// it needs lines of its own.
EncodedValue encodeValue(
  YamlNode value,
  LayoutStyle style, {
  required int indicatorColumn,
}) {
  if (_spansOwnLines(value)) {
    return EncodedValue(
      text: yamlEncodeBlock(
          value, indicatorColumn + style.indentStep, style.lineEnding),
      ownLine: true,
    );
  }
  // `yamlEncodeBlock` indents the *body* of a block scalar two columns past the
  // value it is given, which is what we want for a scalar introduced at
  // `indicatorColumn`.
  return EncodedValue(
    text: yamlEncodeBlock(value, indicatorColumn, style.lineEnding),
    ownLine: false,
  );
}

/// Encodes [value] to be written immediately after a `-`, where YAML's compact
/// notation lets a nested block collection share the line.
///
/// The result always follows a single space and never begins a new line.
String encodeAfterDash(
  YamlNode value,
  LayoutStyle style, {
  required int dashColumn,
}) {
  final indent = dashColumn + style.indentStep;
  if (_spansOwnLines(value)) {
    // The encoder indents every line including the first; drop the first line's
    // indentation so the collection can start on the dash's line.
    return yamlEncodeBlock(value, indent, style.lineEnding).substring(indent);
  }
  // A block scalar's body is indented relative to the entry, which starts one
  // step past the dash, not relative to the dash itself.
  return yamlEncodeBlock(value, indent, style.lineEnding);
}

// ---------------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------------

/// Builds the edit that replaces the value at [path] with [value].
///
/// It is an error to call this with a [path] that does not exist, except for a
/// final step naming a key that may be added to a mapping.
SourceEdit buildUpdate(
  CstDocument document,
  List<Object?> path,
  YamlNode value,
) {
  final edit = _buildUpdate(document, path, value);
  final bodyIndent = _blockBodyIndent(document, path, value);
  if (bodyIndent != null) {
    return _preventBlockScalarSwallowing(document, edit, bodyIndent);
  }
  return edit;
}

/// Adjusts [edit] to prevent an inserted or updated block scalar with
/// [bodyIndent] from swallowing subsequent over-indented comments or blank
/// lines (addressing Bug H2RW_0).
SourceEdit _preventBlockScalarSwallowing(
  CstDocument document,
  SourceEdit edit,
  int bodyIndent,
) {
  final endOffset = edit.offset + edit.length;
  var probe = endOffset;

  final breakLength = document.lineBreakLengthAt(probe);
  if (breakLength > 0) {
    probe += breakLength;
  }

  var extraLength = probe - endOffset;
  final buffer = StringBuffer();
  final source = document.source;

  while (probe < source.length) {
    final lineStart = document.lineStartOf(probe);
    if (probe != lineStart) break;

    final lineContentEnd = document.lineContentEndOf(probe);
    final lineBreakEnd = document.lineBreakEndOf(probe);
    final lineBreak = source.substring(lineContentEnd, lineBreakEnd);

    final comment = document.commentInRange(lineStart, lineContentEnd);
    if (comment != null) {
      final column = comment.span.start.offset - lineStart;
      if (document.isWhitespaceRange(lineStart, comment.span.start.offset) &&
          column >= bodyIndent) {
        final commentText =
            source.substring(comment.span.start.offset, lineContentEnd);
        buffer.write('$commentText$lineBreak');
        extraLength += lineBreakEnd - probe;
        probe = lineBreakEnd;
        continue;
      }
      break;
    }

    if (document.isWhitespaceRange(lineStart, lineContentEnd)) {
      final spacesCount = lineContentEnd - lineStart;
      if (document.hasTabInRange(lineStart, lineContentEnd) ||
          spacesCount >= bodyIndent) {
        buffer.write(lineBreak);
        extraLength += lineBreakEnd - probe;
        probe = lineBreakEnd;
        continue;
      }
    }

    break;
  }

  if (extraLength == 0) return edit;

  final lineEnding = document.lineEnding;
  final replacementEnding = edit.replacement.endsWith(lineEnding)
      ? edit.replacement
      : '${edit.replacement}$lineEnding';

  return SourceEdit(
    edit.offset,
    edit.length + extraLength,
    '$replacementEnding$buffer',
  );
}

/// Attaches [comment] to the header line of a block scalar [replacement].
String attachHeaderComment(
  String replacement,
  String comment,
  String lineEnding,
) {
  final breakIndex = replacement.indexOf(lineEnding);
  if (breakIndex != -1) {
    return '${replacement.substring(0, breakIndex)}'
        '$comment'
        '${replacement.substring(breakIndex)}';
  }
  return '$replacement$comment';
}

int? _blockBodyIndent(
  CstDocument document,
  List<Object?> path,
  YamlNode value,
) {
  if (value is YamlScalar) {
    if (value.style != ScalarStyle.LITERAL &&
        value.style != ScalarStyle.FOLDED) {
      return null;
    }
  } else if (!isBlockNode(value)) {
    return null;
  }
  const additionalIndentation = 2;
  if (path.isEmpty) return additionalIndentation;

  final parentPath = path.take(path.length - 1).toList();
  final step = path.last;
  final parent = findNode(document, parentPath);
  if (parent == null) return null;

  switch (parent) {
    case CstBlockSeq():
      if (step is int && step >= 0 && step < parent.entries.length) {
        return document.columnOf(parent.entries[step].dashStart) +
            additionalIndentation;
      }
      return additionalIndentation;
    case CstBlockMap():
      final index = findEntryIndex(parent, step);
      if (index != null) {
        return document.columnOf(parent.entries[index].keyStart) +
            additionalIndentation;
      }
      return document.columnOf(parent.entries.first.keyStart) +
          additionalIndentation;
    case CstFlowPair():
    case CstFlowCollection():
      return null;
    default:
      return additionalIndentation;
  }
}

SourceEdit _buildUpdate(
  CstDocument document,
  List<Object?> path,
  YamlNode value,
) {
  final style = LayoutStyle.of(document);

  if (path.isEmpty) return _replaceRoot(document, style, value);

  final parentPath = path.take(path.length - 1).toList();
  final step = path.last;
  final parent = findNode(document, parentPath);
  if (parent == null) throw PathError(path, parentPath, document.value);

  switch (parent) {
    case CstBlockSeq():
      if (step is! int || step < 0 || step >= parent.entries.length) {
        throw PathError(path, path, parent.value);
      }
      return _replaceBlockSeqValue(
          document, style, parent.entries[step], value);

    case CstFlowSeq():
      if (step is! int || step < 0 || step >= parent.entries.length) {
        throw PathError(path, path, parent.value);
      }
      return _replaceFlowValue(parent.entries[step].value, value);

    case CstBlockMap():
      final index = findEntryIndex(parent, step);
      if (index == null) {
        return _appendBlockMapEntry(document, style, parent, step, value);
      }
      return _replaceBlockMapValue(
          document, style, parent.entries[index], value);

    case CstFlowMap():
      final index = findEntryIndex(parent, step);
      if (index == null) {
        return _appendFlowMapEntry(document, parent, step, value);
      }
      return _replaceFlowMapValue(parent, parent.entries[index], step, value);

    case CstFlowPair():
      if (findEntryIndex(parent, step) == null) {
        final keyText = yamlEncodeFlow(wrapAsYamlNode(step));
        final valueText = yamlEncodeFlow(value);
        final existingText =
            document.source.substring(parent.contentStart, parent.end);
        final replacement = '{$existingText, $keyText: $valueText}';
        return SourceEdit(
            parent.contentStart, parent.end - parent.contentStart, replacement);
      }
      return _replaceFlowValue(parent.pairValue, value);

    default:
      throw PathError.unexpected(
          path, 'Scalar ${parent.value} does not have key $step');
  }
}

/// Extracts any inline comment associated with [oldNode] that would otherwise
/// be lost by replacing [oldNode], and returns the replacement end offset.
({String? commentToAttach, int replaceEnd}) _extractNodeComment(
  CstDocument document,
  CstNode oldNode, {
  required bool newIsBlockScalar,
}) {
  // If oldNode is a block scalar with a header comment inside its span:
  if (oldNode is CstScalar) {
    if (oldNode.headerComment case final headerComment?) {
      final commentText = headerComment.span.text.trimRight();
      return (
        commentToAttach: ' $commentText',
        replaceEnd: oldNode.contentEnd,
      );
    }
  }

  // If oldNode is followed by an inline comment on the same line:
  if (!document.hasLineBreakBefore(oldNode.contentEnd)) {
    final lineBreakEnd = document.lineBreakEndOf(oldNode.contentEnd);
    final trailingComment =
        document.commentInRange(oldNode.contentEnd, lineBreakEnd);
    if (trailingComment != null) {
      if (newIsBlockScalar) {
        final commentText = trailingComment.span.text.trimRight();
        return (
          commentToAttach: ' $commentText',
          replaceEnd: trailingComment.span.end.offset,
        );
      }
      return (commentToAttach: null, replaceEnd: oldNode.contentEnd);
    }
  }

  var replaceEnd = oldNode.contentEnd;
  if (newIsBlockScalar &&
      oldNode.contentEnd > document.lineStartOf(oldNode.contentEnd)) {
    final lineContentEnd = document.lineContentEndOf(oldNode.contentEnd);
    if (lineContentEnd > replaceEnd) {
      replaceEnd = lineContentEnd;
    }
  }

  return (
    commentToAttach: null,
    replaceEnd: replaceEnd,
  );
}

/// Attaches [comment] to [replacement], lifting it to the header line if
/// [isBlockScalar] is true, or appending it otherwise.
String _attachCommentToReplacement(
  String replacement,
  String? comment,
  String lineEnding, {
  required bool isBlockScalar,
}) {
  if (comment == null) return replacement;
  if (isBlockScalar) {
    return attachHeaderComment(replacement, comment, lineEnding);
  }
  return '$replacement$comment';
}

SourceEdit _replaceRoot(
    CstDocument document, LayoutStyle style, YamlNode value) {
  final text = yamlEncodeBlock(value, 0, style.lineEnding);
  final root = document.root;
  if (root == null) {
    // The document holds no node, only blank space and comments. Replacing the
    // root of such a document replaces the document.
    return SourceEdit(0, document.source.length, text);
  }
  final isBlockScalar = value is YamlScalar &&
      (value.style == ScalarStyle.LITERAL || value.style == ScalarStyle.FOLDED);
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    root,
    newIsBlockScalar: isBlockScalar,
  );
  final textToInsert = _attachCommentToReplacement(
    text,
    commentToAttach,
    style.lineEnding,
    isBlockScalar: isBlockScalar,
  );

  return SourceEdit(root.start, replaceEnd - root.start, textToInsert);
}

/// Replaces the value of a block sequence entry.
///
/// The region replaced starts just past the `-` rather than at the value, so
/// that the space between them can be rewritten: going from `- 1` to a nested
/// block collection needs different spacing than going the other way. When a
/// comment sits between the `-` and the value there is nothing to rewrite, so
/// only the value itself is replaced.
SourceEdit _replaceBlockSeqValue(
  CstDocument document,
  LayoutStyle style,
  CstBlockSeqEntry entry,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return SourceEdit(entry.value.start, 0, '');
  }
  if (entry.value.hasProperties && deepEquals(entry.value.value, value)) {
    return _replaceInPlace(document, style, entry.value, value);
  }
  final dashColumn = document.columnOf(entry.dashStart);
  final hasSeparatorWhitespace = entry.value.start - entry.dashStart - 1 > 1;

  if (entry.hasSeparatorComment || hasSeparatorWhitespace) {
    // Leave the comment or extra spaces, and write the value where the old one
    // was.
    return _replaceInPlace(document, style, entry.value, value);
  }
  var encoded = encodeAfterDash(value, style, dashColumn: dashColumn);
  if (entry.value is CstBlockSeq || entry.value is CstBlockMap) {
    if (encoded.isNotEmpty && !encoded.endsWith(style.lineEnding)) {
      encoded += style.lineEnding;
    }
  }

  final isBlockScalar = value is YamlScalar &&
      (value.style == ScalarStyle.LITERAL || value.style == ScalarStyle.FOLDED);
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    entry.value,
    newIsBlockScalar: isBlockScalar,
  );
  final textToInsert = _attachCommentToReplacement(
    ' $encoded',
    commentToAttach,
    style.lineEnding,
    isBlockScalar: isBlockScalar,
  );

  return SourceEdit(
    entry.dashStart + 1,
    replaceEnd - entry.dashStart - 1,
    textToInsert,
  );
}

/// Replaces the value of a block mapping entry, rewriting the space after the
/// `:` when it holds no comment.
SourceEdit _replaceBlockMapValue(
  CstDocument document,
  LayoutStyle style,
  CstBlockMapEntry entry,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return SourceEdit(entry.value.start, 0, '');
  }
  if (entry.value.hasProperties && deepEquals(entry.value.value, value)) {
    return _replaceInPlace(document, style, entry.value, value);
  }
  final keyColumn = document.columnOf(entry.keyStart);
  final encoded = encodeValue(value, style, indicatorColumn: keyColumn);
  final isBlockScalar = value is YamlScalar &&
      (value.style == ScalarStyle.LITERAL || value.style == ScalarStyle.FOLDED);

  final colon = entry.colon;
  if (colon == null) {
    // An explicit key written without a value, as in `? a`.
    final (:commentToAttach, :replaceEnd) = _extractNodeComment(
      document,
      entry.value,
      newIsBlockScalar: isBlockScalar,
    );
    final atLineStart = entry.value.start == 0 ||
        document.hasLineBreakBefore(entry.value.start);
    final linePrefix = atLineStart ? '' : style.lineEnding;

    var fullText = encoded.ownLine
        ? '$linePrefix${' ' * keyColumn}:${style.lineEnding}${encoded.text}'
        : '$linePrefix${' ' * keyColumn}: ${encoded.text}';
    fullText = _attachCommentToReplacement(
      fullText,
      commentToAttach,
      style.lineEnding,
      isBlockScalar: isBlockScalar,
    );

    final followedByBreakOrContent = replaceEnd < document.source.length &&
        !document.hasLineBreakAt(replaceEnd);
    if (atLineStart &&
        followedByBreakOrContent &&
        !fullText.endsWith(style.lineEnding)) {
      fullText = '$fullText${style.lineEnding}';
    }

    return SourceEdit(
        entry.value.start, replaceEnd - entry.value.start, fullText);
  }

  if (entry.hasSeparatorComment) {
    return _replaceInPlace(document, style, entry.value, value);
  }

  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    entry.value,
    newIsBlockScalar: isBlockScalar,
  );
  var textToInsert = encoded.text;

  if (!encoded.ownLine &&
      document.hasLineBreakInRange(colon + 1, entry.value.start)) {
    final endsWithBreak =
        replaceEnd > 0 && document.hasLineBreakBefore(replaceEnd);
    if (endsWithBreak && !textToInsert.endsWith(style.lineEnding)) {
      textToInsert = '$textToInsert${style.lineEnding}';
    }
  }

  // Preserve trailing line break when replacing a block scalar with an inline
  // scalar (K858_0).
  if (entry.value is CstScalar) {
    final oldScalar = entry.value as CstScalar;
    if ((oldScalar.style == ScalarStyle.LITERAL ||
            oldScalar.style == ScalarStyle.FOLDED) &&
        !encoded.ownLine &&
        !isBlockScalar) {
      if (!textToInsert.endsWith(style.lineEnding) &&
          document.hasLineBreakBefore(entry.end) &&
          replaceEnd <= entry.value.end) {
        textToInsert = '$textToInsert${style.lineEnding}';
      }
    }
  }

  if (entry.value is CstBlockSeq || entry.value is CstBlockMap) {
    if (replaceEnd < document.source.length &&
        document.hasLineBreakBefore(replaceEnd) &&
        !document.hasLineBreakAt(replaceEnd) &&
        !textToInsert.endsWith(style.lineEnding)) {
      textToInsert = '$textToInsert${style.lineEnding}';
    }
  }

  final joiner = encoded.ownLine ? style.lineEnding : ' ';
  final fullReplacement = _attachCommentToReplacement(
    '$joiner$textToInsert',
    commentToAttach,
    style.lineEnding,
    isBlockScalar: isBlockScalar,
  );
  return SourceEdit(
    colon + 1,
    replaceEnd - colon - 1,
    fullReplacement,
  );
}

/// Replaces a node without touching anything around it.
///
/// Used when the space before the value cannot be rewritten because it holds a
/// comment. The replacement is written at the column the old value occupied.
SourceEdit _replaceInPlace(
  CstDocument document,
  LayoutStyle style,
  CstNode old,
  YamlNode value,
) {
  if (old is CstEmpty && value.value == null) {
    return SourceEdit(old.start, 0, '');
  }
  final isCollection = value is YamlList || value is YamlMap;
  final column = switch (old) {
    CstBlockSeq() => document.columnOf(old.entries.first.dashStart),
    CstBlockMap() => document.columnOf(old.entries.first.keyStart),
    _ => document.columnOf(old.start),
  };
  final lineStart = document.lineStartOf(old.start);
  final startsOwnLine = document.isWhitespaceRange(lineStart, old.start);
  var text = yamlEncodeBlock(value, column, style.lineEnding);
  if (isCollection) {
    if (!startsOwnLine && _spansOwnLines(value)) {
      text = text.substring(column);
    }
  } else {
    if (startsOwnLine) {
      text = '${' ' * column}$text';
    }
  }

  final isBlockScalar = value is YamlScalar &&
      (value.style == ScalarStyle.LITERAL || value.style == ScalarStyle.FOLDED);
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    old,
    newIsBlockScalar: isBlockScalar,
  );
  text = _attachCommentToReplacement(
    text,
    commentToAttach,
    style.lineEnding,
    isBlockScalar: isBlockScalar,
  );

  final startOffset =
      startsOwnLine ? lineStart : (isCollection ? old.start : old.contentStart);
  return SourceEdit(startOffset, replaceEnd - startOffset, text);
}

/// Replaces a value inside a flow collection, where everything stays on one
/// line and only flow syntax is allowed.
SourceEdit _replaceFlowValue(CstNode old, YamlNode value) {
  if (old is CstEmpty && value.value == null) {
    return SourceEdit(old.start, 0, '');
  }
  final startOffset = (old.hasProperties && deepEquals(old.value, value))
      ? old.contentStart
      : old.start;
  return SourceEdit(startOffset, old.end - startOffset, yamlEncodeFlow(value));
}

/// Replaces the value of a flow mapping entry, writing a `:` if the entry was
/// a bare key such as the `a` in `{a, b}`.
SourceEdit _replaceFlowMapValue(
  CstFlowMap map,
  CstFlowEntry entry,
  Object? key,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return SourceEdit(entry.value.start, 0, '');
  }
  final text = yamlEncodeFlow(value);
  if (entry.colon == null) {
    return SourceEdit(
        entry.value.start, entry.value.end - entry.value.start, ': $text');
  }
  if (entry.value is CstEmpty) {
    final trailingSpace = entry.comma != null ? entry.comma! : map.closeStart;
    return SourceEdit(
        entry.value.start, trailingSpace - entry.value.start, ' $text');
  }
  return _replaceFlowValue(entry.value, value);
}

// ---------------------------------------------------------------------------
// Adding mapping entries
// ---------------------------------------------------------------------------

/// Adds a new `key: value` entry to a block mapping.
///
/// The entry is placed so as to keep the mapping's keys in order if they were
/// already sorted, and appended otherwise.
SourceEdit _appendBlockMapEntry(
  CstDocument document,
  LayoutStyle style,
  CstBlockMap map,
  Object? key,
  YamlNode value,
) {
  final isCompact = map.entries.first.lineStart !=
      document.lineStartOf(map.entries.first.keyStart);
  final rawIndex =
      key == null ? map.entries.length : getMapInsertionIndex(map.value, key);
  final index = (isCompact && rawIndex == 0) ? map.entries.length : rawIndex;
  final column = document.columnOf(map.entries.first.keyStart);
  final encoded = encodeValue(value, style, indicatorColumn: column);
  final keyText = yamlEncodeFlow(wrapAsYamlNode(key));
  final joiner = encoded.ownLine ? style.lineEnding : ' ';
  final entryText = '${' ' * column}$keyText:$joiner${encoded.text}';

  if (index < map.entries.length) {
    // Insert above the entry it should precede, at the start of the line it is
    // written on so that any comment written above it stays with it.
    final before = map.entries[index];
    final lineStart = document.lineStartOf(before.keyStart);
    return SourceEdit(lineStart, 0, '$entryText${style.lineEnding}');
  }
  return _appendLineToBlockCollection(
      document, style, map.entries.last.end, entryText);
}

/// Appends [text] as a new line of a block collection whose last entry ends at
/// [end].
///
/// A block collection's last entry normally ends just past its line break, and
/// then the new line can simply be written at [end]. When the document stops
/// without a final line break there is none to write after, so one is added
/// first.
SourceEdit _appendLineToBlockCollection(
  CstDocument document,
  LayoutStyle style,
  int end,
  String text,
) {
  final endsWithBreak = end > 0 && document.hasLineBreakBefore(end);
  if (endsWithBreak) {
    return SourceEdit(end, 0, '$text${style.lineEnding}');
  }
  return SourceEdit(end, 0, '${style.lineEnding}$text${style.lineEnding}');
}

/// Adds a new `key: value` entry to a flow mapping.
SourceEdit _appendFlowMapEntry(
  CstDocument document,
  CstFlowMap map,
  Object? key,
  YamlNode value,
) {
  final index =
      key == null ? map.entries.length : getMapInsertionIndex(map.value, key);
  final text = '${yamlEncodeFlow(wrapAsYamlNode(key))}: '
      '${yamlEncodeFlow(value)}';
  return _insertIntoFlowCollection(document, map, index, text);
}

// ---------------------------------------------------------------------------
// Inserting into sequences
// ---------------------------------------------------------------------------

/// Builds the edit that inserts [value] at [index] of the sequence at [path].
SourceEdit buildInsert(
  CstDocument document,
  List<Object?> path,
  int index,
  YamlNode value,
) {
  final edit = _buildInsert(document, path, index, value);
  final bodyIndent = _blockScalarInsertBodyIndent(document, path, index, value);
  if (bodyIndent != null) {
    return _preventBlockScalarSwallowing(document, edit, bodyIndent);
  }
  return edit;
}

int? _blockScalarInsertBodyIndent(
  CstDocument document,
  List<Object?> path,
  int index,
  YamlNode value,
) {
  if (value is! YamlScalar ||
      (value.style != ScalarStyle.LITERAL &&
          value.style != ScalarStyle.FOLDED)) {
    return null;
  }
  const additionalIndentation = 2;
  final node = findNode(document, path);
  if (node is CstBlockSeq && node.entries.isNotEmpty) {
    return document.columnOf(node.entries.first.dashStart) +
        additionalIndentation;
  }
  return null;
}

SourceEdit _buildInsert(
  CstDocument document,
  List<Object?> path,
  int index,
  YamlNode value,
) {
  final style = LayoutStyle.of(document);
  final node = findNode(document, path);
  switch (node) {
    case CstBlockSeq():
      return _insertIntoBlockSeq(document, style, node, index, value);
    case CstFlowSeq():
      return _insertIntoFlowCollection(
          document, node, index, yamlEncodeFlow(value));
    default:
      throw PathError.unexpected(
          path, 'Path $path does not point to a YamlList!');
  }
}

SourceEdit _insertIntoBlockSeq(
  CstDocument document,
  LayoutStyle style,
  CstBlockSeq sequence,
  int index,
  YamlNode value,
) {
  final column = document.columnOf(sequence.entries.first.dashStart);
  final text =
      '${' ' * column}- ${encodeAfterDash(value, style, dashColumn: column)}';

  if (index < sequence.entries.length) {
    final before = sequence.entries[index];
    // Insert at the start of the line the entry it precedes is written on, so
    // that a comment written above that entry stays above it.
    //
    // When the entry does not start its own line — as the inner `- 1` of
    // `- - 1` does not — its `lineStart` is where the entry begins rather than
    // where the line does, and the indentation already written before it serves
    // for the new entry too.
    final startsOwnLine = document.columnOf(before.lineStart) == 0;
    if (startsOwnLine) {
      return SourceEdit(before.lineStart, 0, '$text${style.lineEnding}');
    }
    return SourceEdit(
      before.lineStart,
      0,
      '- ${encodeAfterDash(value, style, dashColumn: column)}'
      '${style.lineEnding}${' ' * column}',
    );
  }

  return _appendLineToBlockCollection(
      document, style, sequence.entries.last.end, text);
}

/// Inserts [text] as the entry at [index] of a flow collection.
///
/// Commas are placed by looking at which neighbours exist, rather than by
/// searching the source for one.
SourceEdit _insertIntoFlowCollection(
  CstDocument document,
  CstFlowCollection collection,
  int index,
  String text,
) {
  final entries = collection.entries;
  if (entries.isEmpty) {
    return SourceEdit(collection.closeStart, 0, text);
  }

  if (index < entries.length) {
    // Write the new entry where the entry it precedes begins, followed by a
    // separator. The displaced entry keeps its own leading whitespace and
    // comments.
    final at = entries[index].contentStart;
    return SourceEdit(at, 0, '$text, ');
  }

  // Appending. The new entry goes just before the closing bracket rather than
  // just after the last entry, so that anything written between the two — a
  // comment, or the line break of a multi-line collection — stays where it is.
  final last = entries.last;
  if (last.comma == null) {
    return SourceEdit(collection.closeStart, 0, ', $text');
  }

  // The collection is written in trailing-comma form, so match it rather than
  // adding a separator of our own.
  if (collection.isMultiline) {
    // The closing bracket sits on a line of its own. Line the new entry up
    // with the entry above it and leave the bracket where it was.
    final entryColumn = document.columnOf(last.contentStart);
    final closeColumn = document.columnOf(collection.closeStart);
    final extraIndent = ' ' * (entryColumn - closeColumn).clamp(0, entryColumn);
    return SourceEdit(
        collection.closeStart,
        0,
        '$extraIndent$text,${document.lineEnding}'
        '${' ' * closeColumn}');
  }

  // Everything is on one line. Separate the new entry from the comma before it
  // unless the source already does.
  final spacer = document.hasWhitespaceBefore(collection.closeStart) ? '' : ' ';
  return SourceEdit(collection.closeStart, 0, '$spacer$text,');
}

// ---------------------------------------------------------------------------
// Removal
// ---------------------------------------------------------------------------

/// Builds the edit that removes whatever lives at [path].
SourceEdit buildRemove(CstDocument document, List<Object?> path) {
  final style = LayoutStyle.of(document);

  if (path.isEmpty) return SourceEdit(0, document.source.length, '');

  final parentPath = path.take(path.length - 1).toList();
  final step = path.last;
  final parent = findNode(document, parentPath);
  if (parent == null) throw PathError(path, parentPath, document.value);

  switch (parent) {
    case CstBlockSeq():
      if (step is! int || step < 0 || step >= parent.entries.length) {
        throw PathError(path, path, parent.value);
      }
      final entry = parent.entries[step];
      final isCompact =
          step == 0 && entry.lineStart != document.lineStartOf(entry.dashStart);
      final nextEntryContentStart = step + 1 < parent.entries.length
          ? parent.entries[step + 1].dashStart
          : null;
      return _removeBlockEntry(
        document,
        style,
        entryCount: parent.entries.length,
        lineStart: entry.lineStart,
        contentStart: entry.dashStart,
        end: entry.end,
        collection: parent,
        emptyText: '[]',
        isCompact: isCompact,
        nextEntryContentStart: nextEntryContentStart,
      );

    case CstBlockMap():
      final index = findEntryIndex(parent, step);
      if (index == null) throw PathError(path, path, parent.value);
      final entry = parent.entries[index];
      final isCompact =
          index == 0 && entry.lineStart != document.lineStartOf(entry.keyStart);
      final nextEntryContentStart = index + 1 < parent.entries.length
          ? parent.entries[index + 1].keyStart
          : null;
      return _removeBlockEntry(
        document,
        style,
        entryCount: parent.entries.length,
        lineStart: entry.lineStart,
        contentStart: entry.keyStart,
        end: entry.end,
        collection: parent,
        emptyText: '{}',
        isCompact: isCompact,
        nextEntryContentStart: nextEntryContentStart,
      );

    case CstFlowSeq():
      if (step is! int || step < 0 || step >= parent.entries.length) {
        throw PathError(path, path, parent.value);
      }
      return _removeFlowEntry(document, parent, step);

    case CstFlowMap():
      final index = findEntryIndex(parent, step);
      if (index == null) throw PathError(path, path, parent.value);
      return _removeFlowEntry(document, parent, index);

    case CstFlowPair():
      if (!deepEquals(parent.key.value, step)) {
        throw PathError(path, path, parent.value);
      }
      return SourceEdit(
          parent.contentStart, parent.end - parent.contentStart, '{}');

    default:
      throw PathError.unexpected(
          path, 'Scalar ${parent.value} does not have key $step');
  }
}

/// Removes one entry of a block collection.
///
/// The removed region runs from the start of the entry's own line to just past
/// the line break that ends it, so the entry's indentation and its trailing
/// comment go with it while any comment written above it stays.
///
/// A block collection cannot be written with no entries at all, so removing the
/// last one replaces the whole collection with its flow spelling, `[]` or `{}`.
SourceEdit _removeBlockEntry(
  CstDocument document,
  LayoutStyle style, {
  required int entryCount,
  required int lineStart,
  required int contentStart,
  required int end,
  required CstNode collection,
  required String emptyText,
  required bool isCompact,
  required int? nextEntryContentStart,
}) {
  if (entryCount == 1) {
    final breakLength = document.lineBreakLengthBefore(end);
    final column = document.columnOf(contentStart);
    final text = (column == 0 && document.hasLineBreakBefore(contentStart))
        ? '  $emptyText'
        : emptyText;
    return SourceEdit(contentStart, end - breakLength - contentStart, text);
  }

  int startOffset;
  int endOffset;

  if (isCompact && nextEntryContentStart != null) {
    final nextLineStart = document.lineStartOf(nextEntryContentStart);
    final nextIndentLength = nextEntryContentStart - nextLineStart;
    final isImmediatelyNextLine = nextLineStart == end;
    startOffset = contentStart;
    endOffset = isImmediatelyNextLine ? end + nextIndentLength : end;
  } else {
    startOffset = document.lineStartOf(contentStart);
    endOffset = end;

    // Extend endOffset past any trailing blank lines and comments indented more
    // than the collection's indentation.
    final collectionIndent = switch (collection) {
      CstBlockSeq() => document.columnOf(collection.entries.first.dashStart),
      CstBlockMap() => document.columnOf(collection.entries.first.keyStart),
      _ => 0,
    };

    endOffset = document.extendPastIndentedCommentsAndBlankLines(
        endOffset, collectionIndent);
  }

  return SourceEdit(startOffset, endOffset - startOffset, '');
}

/// Removes one entry of a flow collection, along with the comma that separates
/// it from its neighbours, while preserving any leading full-line comments and
/// sibling trailing comments.
SourceEdit _removeFlowEntry(
  CstDocument document,
  CstFlowCollection collection,
  int index,
) {
  final entries = collection.entries;
  final entry = entries[index];

  if (entries.length == 1) {
    return SourceEdit(
        collection.openEnd, collection.closeStart - collection.openEnd, '');
  }

  if (index == 0) {
    final comma = entry.comma;
    if (comma != null) {
      if (collection is CstFlowSeq) {
        final commentsInEntry =
            document.commentsInRange(entry.value.end, comma);
        final ownLineComments = commentsInEntry
            .where((c) =>
                document.lineStartOf(c.span.start.offset) >
                document.lineStartOf(entry.contentStart))
            .toList();
        if (ownLineComments.isNotEmpty) {
          final preserved = document.source.substring(entry.value.end, comma);
          return SourceEdit(
            entry.contentStart,
            (comma + 1) - entry.contentStart,
            preserved,
          );
        }
      }

      final commentsBefore =
          document.commentsInRange(collection.openEnd, entry.contentStart);
      final nextContent = entries[1].contentStart;
      final commentsAfterComma =
          document.commentsInRange(comma + 1, nextContent);

      if (commentsBefore.isNotEmpty) {
        if (!document.hasLineBreakInRange(comma + 1, nextContent)) {
          return SourceEdit(
              entry.contentStart, nextContent - entry.contentStart, '');
        }
        final start =
            document.lineBreakEndOf(commentsBefore.last.span.end.offset);
        final end = commentsAfterComma.isNotEmpty &&
                document.lineStartOf(
                        commentsAfterComma.first.span.start.offset) ==
                    document.lineStartOf(comma)
            ? document.lineBreakEndOf(commentsAfterComma.first.span.end.offset)
            : document.lineBreakEndOf(comma);
        return SourceEdit(start, end - start, '');
      }

      var end = comma + 1;
      if (commentsAfterComma.isNotEmpty) {
        final comment = commentsAfterComma.first;
        if (document.lineStartOf(comment.span.start.offset) ==
            document.lineStartOf(comma)) {
          end = document.lineBreakEndOf(comment.span.end.offset);
        }
      }
      return SourceEdit(collection.openEnd, end - collection.openEnd, '');
    }
    final commentsBefore =
        document.commentsInRange(collection.openEnd, entry.contentStart);
    final start = commentsBefore.isNotEmpty
        ? document.lineBreakEndOf(commentsBefore.last.span.end.offset)
        : collection.openEnd;
    final next = entries[1];
    return SourceEdit(start, next.contentStart - start, '');
  }

  if (index < entries.length - 1) {
    final next = entries[index + 1];
    final entryEnd = entry.comma != null ? entry.comma! + 1 : entry.end;
    final commentsAfter = document.commentsInRange(entryEnd, next.contentStart);
    if (commentsAfter.isNotEmpty) {
      final comment = commentsAfter.first;
      final lineBreakEnd = document.lineBreakEndOf(comment.span.end.offset);
      final previous = entries[index - 1];
      final previousEnd =
          previous.comma != null ? previous.comma! + 1 : previous.end;
      final commentsBefore =
          document.commentsInRange(previousEnd, entry.contentStart);
      final start = commentsBefore.isNotEmpty
          ? document.lineBreakEndOf(commentsBefore.last.span.end.offset)
          : entry.contentStart;
      return SourceEdit(start, lineBreakEnd - start, '');
    }
    return SourceEdit(
        entry.contentStart, next.contentStart - entry.contentStart, '');
  }

  final previous = entries[index - 1];
  final from = previous.comma ?? previous.end;
  final previousEnd =
      previous.comma != null ? previous.comma! + 1 : previous.end;
  final commentsBefore =
      document.commentsInRange(previousEnd, entry.contentStart);
  if (commentsBefore.isNotEmpty) {
    final deleteStart =
        document.lineBreakEndOf(commentsBefore.last.span.end.offset);
    return SourceEdit(deleteStart, collection.closeStart - deleteStart, '');
  }

  final commentsAfter =
      document.commentsInRange(entry.value.end, collection.closeStart);
  if (commentsAfter.isNotEmpty) {
    final firstComment = commentsAfter.first;
    if (document.lineStartOf(firstComment.span.start.offset) >
        document.lineStartOf(entry.contentStart)) {
      final deleteEnd = document.lineBreakEndOf(entry.value.end);
      return SourceEdit(from, deleteEnd - from, '');
    }
  }

  return SourceEdit(from, collection.closeStart - from, '');
}
