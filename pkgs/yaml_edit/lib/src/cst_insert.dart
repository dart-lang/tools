// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cst_mutations.dart';

// ---------------------------------------------------------------------------
// Adding mapping entries
// ---------------------------------------------------------------------------

/// Adds a new `key: value` entry to a block mapping.
///
/// The entry is placed so as to keep the mapping's keys in order if they were
/// already sorted, and appended otherwise.
_MutationEdit _appendBlockMapEntry(
  CstDocument document,
  LayoutStyle style,
  CstBlockMap map,
  Object? key,
  YamlNode value,
) {
  final rawIndex =
      key == null ? map.entries.length : getMapInsertionIndex(map.value, key);
  final index =
      (map.isCompact && rawIndex == 0) ? map.entries.length : rawIndex;
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
    return (
      edit: SourceEdit(lineStart, 0, '$entryText${style.lineEnding}'),
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }
  return (
    edit: _appendLineToBlockCollection(
        document, style, map.entries.last.end, entryText),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
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
  final (:edit, :trailingBlockScalarBodyIndent) =
      _buildInsert(document, path, index, value);
  if (trailingBlockScalarBodyIndent != null) {
    final entryColumn = _entryColumnForInsert(document, path);
    return _preventBlockScalarSwallowing(
      document,
      edit,
      bodyIndent: trailingBlockScalarBodyIndent,
      targetColumn: min(entryColumn, trailingBlockScalarBodyIndent - 1),
    );
  }
  return edit;
}

int _entryColumnForInsert(CstDocument document, List<Object?> path) {
  final parent = findNode(document, path);
  if (parent is CstBlockSeq && parent.entries.isNotEmpty) {
    return document.columnOf(parent.entries.first.dashStart);
  }
  return 0;
}

_MutationEdit _buildInsert(
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
      return (
        edit: _insertIntoFlowCollection(
            document, node, index, yamlEncodeFlow(value)),
        trailingBlockScalarBodyIndent: null,
      );
    default:
      throw PathError.unexpected(
          path, 'Path $path does not point to a YamlList!');
  }
}

_MutationEdit _insertIntoBlockSeq(
  CstDocument document,
  LayoutStyle style,
  CstBlockSeq sequence,
  int index,
  YamlNode value,
) {
  final column = document.columnOf(sequence.entries.first.dashStart);
  final encoded = encodeAfterDash(value, style, dashColumn: column);
  final text = '${' ' * column}- ${encoded.text}';

  if (index < sequence.entries.length) {
    final before = sequence.entries[index];
    // Insert at the start of the line the entry it precedes is written on, so
    // that a comment written above that entry stays above it.
    //
    // When inserting before the first entry of a compact sequence (such as
    // `- - 1`), the outer indicator already supplies the indentation for the
    // new entry, so write the displaced entry's indentation after the line
    // break.
    if (index == 0 && sequence.isCompact) {
      return (
        edit: SourceEdit(
          before.dashStart,
          0,
          '- ${encoded.text}${style.lineEnding}${' ' * column}',
        ),
        trailingBlockScalarBodyIndent: null,
      );
    }
    return (
      edit: SourceEdit(before.lineStart, 0, '$text${style.lineEnding}'),
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }

  return (
    edit: _appendLineToBlockCollection(
        document, style, sequence.entries.last.end, text),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
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
