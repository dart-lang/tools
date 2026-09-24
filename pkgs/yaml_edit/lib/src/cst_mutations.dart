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
      if (childIndent != 0) indentStep = childIndent;
    }
    return LayoutStyle(
      indentStep: indentStep,
      lineEnding: getLineEnding(document.source),
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
  return _preventBlockScalarSwallowingComments(document, edit);
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
  var lineEnd = oldNode.contentEnd;
  final atLineBoundary = oldNode.contentEnd > 0 &&
      (document.source[oldNode.contentEnd - 1] == '\n' ||
          document.source[oldNode.contentEnd - 1] == '\r');
  while (!atLineBoundary &&
      lineEnd < document.source.length &&
      document.source[lineEnd] != '\n' &&
      document.source[lineEnd] != '\r') {
    lineEnd++;
  }
  final trailingLine = document.source.substring(oldNode.contentEnd, lineEnd);
  if (trailingLine.contains('#')) {
    if (newIsBlockScalar) {
      return (commentToAttach: trailingLine, replaceEnd: lineEnd);
    }
    // Leave trailingLine in place after oldNode.contentEnd.
    return (commentToAttach: null, replaceEnd: oldNode.contentEnd);
  }

  // If oldNode is a block scalar with a header comment inside its span,
  // replacing oldNode.contentEnd will delete that comment unless we extract it.
  if (oldNode is CstScalar &&
      (oldNode.style == ScalarStyle.LITERAL ||
          oldNode.style == ScalarStyle.FOLDED)) {
    final text = document.source.substring(oldNode.contentStart, oldNode.end);
    final firstNl = text.indexOf('\n');
    if (firstNl != -1) {
      var headerLine = text.substring(0, firstNl);
      if (headerLine.endsWith('\r')) {
        headerLine = headerLine.substring(0, headerLine.length - 1);
      }
      final hashIdx = headerLine.indexOf('#');
      if (hashIdx != -1) {
        var commentStart = hashIdx;
        while (commentStart > 0 &&
            (headerLine[commentStart - 1] == ' ' ||
                headerLine[commentStart - 1] == '\t')) {
          commentStart--;
        }
        var comment = headerLine.substring(commentStart);
        if (!comment.startsWith(' ') && !comment.startsWith('\t')) {
          comment = ' $comment';
        }
        return (commentToAttach: comment, replaceEnd: oldNode.contentEnd);
      }
    }
  }

  return (
    commentToAttach: null,
    replaceEnd: newIsBlockScalar ? lineEnd : oldNode.contentEnd,
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
    final firstBreak = replacement.indexOf(lineEnding);
    if (firstBreak != -1) {
      return '${replacement.substring(0, firstBreak)}'
          '$comment'
          '${replacement.substring(firstBreak)}';
    }
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
  final isBlockScalar = (text.startsWith('|') || text.startsWith('>')) &&
      text.contains(style.lineEnding);
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
  final dashColumn = document.columnOf(entry.dashStart);
  final separator =
      document.source.substring(entry.dashStart + 1, entry.value.start);

  if (separator.contains('#') || separator.length > 1) {
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

  final isBlockScalar = (encoded.startsWith('|') || encoded.startsWith('>')) &&
      encoded.contains(style.lineEnding);
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
  final keyColumn = document.columnOf(entry.keyStart);
  final encoded = encodeValue(value, style, indicatorColumn: keyColumn);
  final isBlockScalar =
      (encoded.text.startsWith('|') || encoded.text.startsWith('>')) &&
          encoded.text.contains(style.lineEnding);

  final colon = entry.colon;
  if (colon == null) {
    // An explicit key written without a value, as in `? a`.
    final (:commentToAttach, :replaceEnd) = _extractNodeComment(
      document,
      entry.value,
      newIsBlockScalar: isBlockScalar,
    );
    final atLineStart = entry.value.start == 0 ||
        document.source[entry.value.start - 1] == '\n' ||
        document.source[entry.value.start - 1] == '\r';
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
        (document.source[replaceEnd] != '\n' &&
            document.source[replaceEnd] != '\r');
    if (atLineStart &&
        followedByBreakOrContent &&
        !fullText.endsWith(style.lineEnding)) {
      fullText = '$fullText${style.lineEnding}';
    }

    return SourceEdit(
        entry.value.start, replaceEnd - entry.value.start, fullText);
  }

  final separator = document.source.substring(colon + 1, entry.value.start);
  if (separator.contains('#')) {
    return _replaceInPlace(document, style, entry.value, value);
  }

  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    entry.value,
    newIsBlockScalar: isBlockScalar,
  );
  var textToInsert = encoded.text;

  if (!encoded.ownLine &&
      document.source.substring(colon + 1, entry.value.start).contains('\n')) {
    final endsWithBreak = replaceEnd > 0 &&
        (document.source[replaceEnd - 1] == '\n' ||
            document.source[replaceEnd - 1] == '\r');
    if (endsWithBreak && !textToInsert.endsWith(style.lineEnding)) {
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
  final column = switch (old) {
    CstBlockSeq() => document.columnOf(old.entries.first.dashStart),
    CstBlockMap() => document.columnOf(old.entries.first.keyStart),
    _ => document.columnOf(old.contentStart),
  };
  final startsOwnLine = document.columnOf(old.start) == 0;
  var text = yamlEncodeBlock(value, column, style.lineEnding);
  if (value is YamlList || value is YamlMap) {
    if (!startsOwnLine && _spansOwnLines(value)) {
      text = text.substring(column);
    }
  } else {
    if (startsOwnLine) {
      text = '${' ' * column}$text';
    }
  }

  final trimmedText = text.trimLeft();
  final isBlockScalar =
      (trimmedText.startsWith('|') || trimmedText.startsWith('>')) &&
          text.contains(style.lineEnding);
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

  return SourceEdit(old.start, replaceEnd - old.start, text);
}

/// Replaces a value inside a flow collection, where everything stays on one
/// line and only flow syntax is allowed.
SourceEdit _replaceFlowValue(CstNode old, YamlNode value) {
  final length = old.value.span.length;
  return SourceEdit(old.value.span.start.offset, length, yamlEncodeFlow(value));
}

/// Replaces the value of a flow mapping entry, writing a `:` if the entry was
/// a bare key such as the `a` in `{a, b}`.
SourceEdit _replaceFlowMapValue(
  CstFlowMap map,
  CstFlowEntry entry,
  Object? key,
  YamlNode value,
) {
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
      document, style, map.entries.last.end, entryText, map.entries.last);
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
  Object lastEntry,
) {
  final endsWithBreak = end > 0 &&
      (document.source[end - 1] == '\n' || document.source[end - 1] == '\r');
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
  return _preventBlockScalarSwallowingComments(document, edit);
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
  CstBlockSeq seq,
  int index,
  YamlNode value,
) {
  final column = document.columnOf(seq.entries.first.dashStart);
  final text =
      '${' ' * column}- ${encodeAfterDash(value, style, dashColumn: column)}';

  if (index < seq.entries.length) {
    final before = seq.entries[index];
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
      document, style, seq.entries.last.end, text, seq.entries.last);
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
  final gap = document.source.substring(last.value.end, collection.closeStart);

  if (last.comma == null) {
    return SourceEdit(collection.closeStart, 0, ', $text');
  }

  // The collection is written in trailing-comma form, so match it rather than
  // adding a separator of our own.
  if (gap.contains('\n')) {
    // The closing bracket sits on a line of its own. Line the new entry up
    // with the entry above it and leave the bracket where it was.
    final entryColumn = document.columnOf(last.contentStart);
    final closeColumn = document.columnOf(collection.closeStart);
    final extraIndent = ' ' * (entryColumn - closeColumn).clamp(0, entryColumn);
    return SourceEdit(
        collection.closeStart,
        0,
        '$extraIndent$text,${getLineEnding(document.source)}'
        '${' ' * closeColumn}');
  }

  // Everything is on one line. Separate the new entry from the comma before it
  // unless the source already does.
  final spacer = gap.endsWith(' ') || gap.endsWith('\t') ? '' : ' ';
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
    final hasBreak = end > 0 &&
        (document.source[end - 1] == '\n' || document.source[end - 1] == '\r');
    final breakLen = hasBreak
        ? (end > 1 &&
                document.source[end - 2] == '\r' &&
                document.source[end - 1] == '\n'
            ? 2
            : 1)
        : 0;
    final col = document.columnOf(contentStart);
    final text = (col == 0 &&
            contentStart > 0 &&
            (document.source[contentStart - 1] == '\n' ||
                document.source[contentStart - 1] == '\r'))
        ? '  $emptyText'
        : emptyText;
    return SourceEdit(contentStart, end - breakLen - contentStart, text);
  }

  final src = document.source;
  final len = src.length;

  int startOffset;
  int endOffset;

  if (isCompact && nextEntryContentStart != null) {
    // When removing the first entry of a compact collection that has
    // subsequent entries, we want the next entry to become compact only if it
    // immediately follows on the next line.
    final nextLineStart = document.lineStartOf(nextEntryContentStart);
    final nextIndentLength = nextEntryContentStart - nextLineStart;
    final trueEndOffset = end - 1;
    final nearestLineEndingBeforeNext =
        src.lastIndexOf('\n', nextEntryContentStart);
    final isImmediatelyNextLine = nearestLineEndingBeforeNext == trueEndOffset;
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

    var probe = endOffset;
    while (probe < len) {
      var lineScan = probe;
      while (
          lineScan < len && (src[lineScan] == ' ' || src[lineScan] == '\t')) {
        lineScan++;
      }
      if (lineScan >= len) {
        endOffset = len;
        break;
      }
      final ch = src[lineScan];
      if (ch == '\n' || ch == '\r') {
        // Completely blank line!
        if (ch == '\r' && lineScan + 1 < len && src[lineScan + 1] == '\n') {
          probe = lineScan + 2;
        } else {
          probe = lineScan + 1;
        }
        endOffset = probe;
        continue;
      }
      if (ch == '#') {
        final lineIndent = lineScan - probe;
        if (lineIndent > collectionIndent) {
          // Indented comment, consume whole line
          while (lineScan < len &&
              src[lineScan] != '\n' &&
              src[lineScan] != '\r') {
            lineScan++;
          }
          if (lineScan < len &&
              src[lineScan] == '\r' &&
              lineScan + 1 < len &&
              src[lineScan + 1] == '\n') {
            probe = lineScan + 2;
          } else if (lineScan < len) {
            probe = lineScan + 1;
          } else {
            probe = lineScan;
          }
          endOffset = probe;
          continue;
        }
      }
      break;
    }
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
  final src = document.source;
  final entries = collection.entries;
  final entry = entries[index];

  if (entries.length == 1) {
    return SourceEdit(
        collection.openEnd, collection.closeStart - collection.openEnd, '');
  }

  if (index == 0) {
    final comma = entry.comma;
    if (comma != null) {
      final beforeEntry = src.substring(collection.openEnd, entry.contentStart);
      final nextContent = entries[1].contentStart;
      final afterComma = src.substring(comma + 1, nextContent);
      if (beforeEntry.contains('#') &&
          !src.substring(entry.contentStart, comma).contains('\n')) {
        if (!afterComma.contains('\n')) {
          return SourceEdit(
              entry.contentStart, nextContent - entry.contentStart, '');
        }
        final lastNl = beforeEntry.lastIndexOf('\n');
        final start =
            lastNl != -1 ? collection.openEnd + lastNl + 1 : entry.contentStart;
        final nl = afterComma.indexOf('\n');
        final end = comma + 1 + nl + 1;
        return SourceEdit(start, end - start, '');
      }
      var end = comma + 1;
      final nl = afterComma.indexOf('\n');
      final sameLineAfterComma =
          nl != -1 ? afterComma.substring(0, nl) : afterComma;
      if (sameLineAfterComma.contains('#')) {
        end += nl != -1 ? nl : afterComma.length;
      }
      return SourceEdit(collection.openEnd, end - collection.openEnd, '');
    }
    final next = entries[1];
    return SourceEdit(
        collection.openEnd, next.contentStart - collection.openEnd, '');
  }

  if (index < entries.length - 1) {
    final next = entries[index + 1];
    final entryEnd = entry.comma != null ? entry.comma! + 1 : entry.end;
    final afterEntry = src.substring(entryEnd, next.contentStart);
    if (afterEntry.contains('#')) {
      final nl = afterEntry.indexOf('\n');
      if (nl != -1) {
        final prev = entries[index - 1];
        final prevEnd = prev.comma != null ? prev.comma! + 1 : prev.end;
        final beforeEntry = src.substring(prevEnd, entry.contentStart);
        final lastNl = beforeEntry.lastIndexOf('\n');
        final start = lastNl != -1 ? prevEnd + lastNl + 1 : entry.contentStart;
        return SourceEdit(start, (entryEnd + nl + 1) - start, '');
      }
    }
    return SourceEdit(
        entry.contentStart, next.contentStart - entry.contentStart, '');
  }

  final previous = entries[index - 1];
  final from = previous.comma ?? previous.end;
  final prevEnd = previous.comma != null ? previous.comma! + 1 : previous.end;
  final beforeEntry = src.substring(prevEnd, entry.contentStart);
  final lastNl = beforeEntry.lastIndexOf('\n');
  if (beforeEntry.contains('#') && lastNl != -1) {
    return SourceEdit(from, collection.closeStart - from,
        beforeEntry.substring(0, lastNl + 1));
  }
  return SourceEdit(from, collection.closeStart - from, '');
}

/// Prevents an inserted or updated block scalar from swallowing subsequent
/// comment lines that happen to be indented at or beyond the scalar's
/// indentation level.
///
/// In YAML, a block scalar continues until indentation drops below its body
/// indentation, and `#` characters on lines indented at or beyond that level
/// are parsed as literal text rather than comments. When comments following
/// the edit have indentation greater than or equal to the scalar's body, they
/// are re-indented to column 0 so they remain comments.
SourceEdit _preventBlockScalarSwallowingComments(
  CstDocument document,
  SourceEdit edit,
) {
  final text = edit.replacement;
  final lines = text.split('\n');
  int? headerLineIndex;
  final headerPattern = RegExp(r'(?:^|[\s:-])([|>][+-]?)(?:\s+#.*)?$');
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    if (headerPattern.hasMatch(line)) {
      headerLineIndex = i;
      break;
    }
  }

  if (headerLineIndex == null) return edit;

  int? bodyIndent;
  for (var i = headerLineIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isNotEmpty) {
      bodyIndent = line.length - line.trimLeft().length;
      break;
    }
  }

  if (bodyIndent == null || bodyIndent == 0) return edit;

  final endOffset = edit.offset + edit.length;
  var pos = endOffset;
  if (pos < document.source.length &&
      (document.source[pos] == '\n' || document.source[pos] == '\r')) {
    if (pos + 1 < document.source.length &&
        document.source[pos] == '\r' &&
        document.source[pos + 1] == '\n') {
      pos += 2;
    } else {
      pos += 1;
    }
  }
  var extraLength = pos - endOffset;
  final buffer = StringBuffer();

  while (pos < document.source.length) {
    var lineEnd = pos;
    while (lineEnd < document.source.length &&
        document.source[lineEnd] != '\n' &&
        document.source[lineEnd] != '\r') {
      lineEnd++;
    }
    final nextBreak = lineEnd < document.source.length
        ? (lineEnd + 1 < document.source.length &&
                document.source[lineEnd] == '\r' &&
                document.source[lineEnd + 1] == '\n'
            ? lineEnd + 2
            : lineEnd + 1)
        : lineEnd;

    final line = document.source.substring(pos, lineEnd);
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) {
      final col = line.length - trimmed.length;
      if (col >= bodyIndent) {
        final breakChars = document.source.substring(lineEnd, nextBreak);
        buffer.write('$trimmed$breakChars');
        extraLength += nextBreak - pos;
        pos = nextBreak;
        continue;
      }
    }
    break;
  }

  if (buffer.isEmpty) return edit;

  final rep = edit.replacement.endsWith('\n') || edit.replacement.endsWith('\r')
      ? edit.replacement
      : '${edit.replacement}\n';

  return SourceEdit(
    edit.offset,
    edit.length + extraLength,
    '$rep$buffer',
  );
}
