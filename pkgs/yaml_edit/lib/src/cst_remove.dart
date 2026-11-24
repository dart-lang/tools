// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cst_mutations.dart';

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
      final nextEntryContentStart = step + 1 < parent.entries.length
          ? parent.entries[step + 1].dashStart
          : null;
      int? parentKeyColumn;
      if (parent.entries.length == 1 && parentPath.isNotEmpty) {
        final grandParent =
            findNode(document, parentPath.sublist(0, parentPath.length - 1));
        if (grandParent is CstBlockMap) {
          final grandParentIndex = findEntryIndex(grandParent, parentPath.last);
          if (grandParentIndex != null) {
            parentKeyColumn = document
                .columnOf(grandParent.entries[grandParentIndex].keyStart);
          }
        }
      }
      return _removeBlockEntry(
        document,
        style,
        entryCount: parent.entries.length,
        contentStart: entry.dashStart,
        end: entry.end,
        collection: parent,
        emptyText: '[]',
        isCompact: step == 0 && parent.isCompact,
        nextEntryContentStart: nextEntryContentStart,
        parentKeyColumn: parentKeyColumn,
      );

    case CstBlockMap():
      final index = findEntryIndex(parent, step);
      if (index == null) throw PathError(path, path, parent.value);
      final entry = parent.entries[index];
      final nextEntryContentStart = index + 1 < parent.entries.length
          ? parent.entries[index + 1].keyStart
          : null;
      return _removeBlockEntry(
        document,
        style,
        entryCount: parent.entries.length,
        contentStart: entry.keyStart,
        end: entry.end,
        collection: parent,
        emptyText: '{}',
        isCompact: index == 0 && parent.isCompact,
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
  required int contentStart,
  required int end,
  required CstNode collection,
  required String emptyText,
  required bool isCompact,
  required int? nextEntryContentStart,
  int? parentKeyColumn,
}) {
  if (entryCount == 1) {
    final breakLength = document.lineBreakLengthBefore(end);
    final column = document.columnOf(contentStart);
    final needsIndent = _startsOwnLine(document, contentStart) &&
        parentKeyColumn != null &&
        column <= parentKeyColumn;
    final extraSpaces =
        needsIndent ? ' ' * (parentKeyColumn - column + style.indentStep) : '';
    return SourceEdit(
      contentStart,
      end - breakLength - contentStart,
      '$extraSpaces$emptyText',
    );
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

    // Preserve section-separating blank lines after a removed last entry
    // unless the preceding entry ends with a keep-chomped block scalar (`|+`
    // or `>+`), which would otherwise absorb those blank lines.
    final preserveTrailingBlankLines = nextEntryContentStart == null &&
        switch (collection) {
          CstBlockSeq() => !_endsWithKeepBlockScalar(
              document,
              collection.entries[entryCount - 2].value,
            ),
          CstBlockMap() => !_endsWithKeepBlockScalar(
              document,
              collection.entries[entryCount - 2].value,
            ),
          _ => true,
        };

    endOffset = document.extendPastIndentedCommentsAndBlankLines(
      endOffset,
      collectionIndent,
      preserveTrailingBlankLines: preserveTrailingBlankLines,
    );
  }

  return SourceEdit(startOffset, endOffset - startOffset, '');
}

bool _endsWithKeepBlockScalar(CstDocument document, CstNode node) =>
    switch (node) {
      CstScalar() => (node.value.style == ScalarStyle.LITERAL ||
              node.value.style == ScalarStyle.FOLDED) &&
          document.source
              .substring(
                node.contentStart,
                node.headerComment?.span.start.offset ??
                    document.lineContentEndOf(node.contentStart),
              )
              .contains('+'),
      CstBlockSeq() =>
        _endsWithKeepBlockScalar(document, node.entries.last.value),
      CstBlockMap() =>
        _endsWithKeepBlockScalar(document, node.entries.last.value),
      _ => false,
    };

// ---------------------------------------------------------------------------
// Flow collection removal
// ---------------------------------------------------------------------------

/// Whether [offset] is preceded only by spaces/tabs on its line.
bool _startsOwnLine(CstDocument document, int offset) =>
    document.isWhitespaceRange(document.lineStartOf(offset), offset);

/// Returns the first comment in `[offset, limit)` if it sits on the same line
/// as [offset], or `null` otherwise.
YamlToken? _sameLineCommentAfter(
  CstDocument document,
  int offset,
  int limit,
) {
  final comments = document.commentsInRange(offset, limit);
  if (comments.isEmpty) return null;
  final first = comments.first;
  return document.lineStartOf(first.span.start.offset) ==
          document.lineStartOf(offset)
      ? first
      : null;
}

/// Returns the offset just past the line break of the last comment in
/// `[start, end)`, or `null` if that range contains no comments.
int? _lastCommentBreakEnd(CstDocument document, int start, int end) {
  final comments = document.commentsInRange(start, end);
  if (comments.isEmpty) return null;
  return document.lineBreakEndOf(comments.last.span.end.offset);
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
  if (entries.length == 1) {
    return SourceEdit(
      collection.openEnd,
      collection.closeStart - collection.openEnd,
      '',
    );
  }
  if (index == 0) {
    return _removeFirstFlowEntry(document, collection);
  }
  if (index < entries.length - 1) {
    return _removeMiddleFlowEntry(document, collection, index);
  }
  return _removeLastFlowEntry(document, collection);
}

/// Removes the first entry of a multi-entry flow collection (along with its
/// trailing `,`).
///
/// ```text
///   [ # above          -->  [ # above
///     a, # inline             b]
///     b]
///   ^---- deleted: [after `# above\n`, after `# inline\n`)
///
///   {\n  foo:,bar:true\n}  -->  {bar:true\n}
///    ^-------- deleted from `openEnd` to `comma + 1` (matches legacy golden)
/// ```
SourceEdit _removeFirstFlowEntry(
  CstDocument document,
  CstFlowCollection collection,
) {
  final entry = collection.entries[0];
  final nextContent = collection.entries[1].contentStart;
  // `_checkTiling` guarantees every non-final flow entry has a `,`.
  final comma = entry.comma!;

  // In a flow sequence, own-line comments placed between the first value and a
  // standalone `,` on a later line (`[a\n# c\n, b]`) are preserved by splicing
  // them back. Flow mappings intentionally drop comments inside
  // `[contentStart, comma)` to match legacy `remove_flow_map.golden` case `G`.
  if (collection is CstFlowSeq) {
    final spliceEdit = _tryRemoveFirstFlowSeqEntryWithPreCommaComments(
      document,
      entry,
      comma: comma,
      nextContent: nextContent,
    );
    if (spliceEdit != null) return spliceEdit;
  }

  final commentBeforeEnd =
      _lastCommentBreakEnd(document, collection.openEnd, entry.contentStart);
  final inlineComment = _sameLineCommentAfter(document, comma + 1, nextContent);

  if (commentBeforeEnd != null) {
    if (!document.hasLineBreakInRange(comma + 1, nextContent)) {
      return SourceEdit(
          entry.contentStart, nextContent - entry.contentStart, '');
    }
    final end = document.lineBreakEndOf(
      inlineComment?.span.end.offset ?? comma,
    );
    return SourceEdit(commentBeforeEnd, end - commentBeforeEnd, '');
  }

  var start = collection.openEnd;
  var end = comma + 1;
  if (inlineComment != null) {
    final entryLineStart = document.lineStartOf(entry.contentStart);
    if (entryLineStart > document.lineStartOf(collection.openEnd) &&
        _startsOwnLine(document, entry.contentStart)) {
      start = entryLineStart;
    }
    end = document.lineBreakEndOf(inlineComment.span.end.offset);
  }
  return SourceEdit(start, end - start, '');
}

/// Handles removing the first entry of a [CstFlowSeq] when own-line comments
/// appear between the value and its comma:
///
/// ```text
///   [
///     a
///     # keep me
///     , b
///   ]
///   ==>
///   [
///     # keep me
///     b
///   ]
/// ```
SourceEdit? _tryRemoveFirstFlowSeqEntryWithPreCommaComments(
  CstDocument document,
  CstFlowEntry entry, {
  required int comma,
  required int nextContent,
}) {
  final ownLineComments = document
      .commentsInRange(entry.value.end, comma)
      .where((c) =>
          document.lineStartOf(c.span.start.offset) >
          document.lineStartOf(entry.value.end))
      .toList();
  if (ownLineComments.isEmpty) return null;

  final entryLineStart = document.lineStartOf(entry.contentStart);
  final startsOwnLine = _startsOwnLine(document, entry.contentStart);
  final preservedComments = document.source.substring(
    document.lineStartOf(ownLineComments.first.span.start.offset),
    document.lineBreakEndOf(ownLineComments.last.span.end.offset),
  );
  final deleteStart = startsOwnLine ? entryLineStart : entry.contentStart;
  final prefixBreak = startsOwnLine ? '' : document.lineEnding;

  final commaLineStart = document.lineStartOf(comma);
  if (document.lineStartOf(nextContent) == commaLineStart) {
    final commaIndent = document.source.substring(commaLineStart, comma);
    return SourceEdit(
      deleteStart,
      nextContent - deleteStart,
      '$prefixBreak$preservedComments$commaIndent',
    );
  }
  final inlineAfterComma =
      _sameLineCommentAfter(document, comma + 1, nextContent);
  final deleteEnd = document.lineBreakEndOf(
    inlineAfterComma?.span.end.offset ?? comma,
  );
  return SourceEdit(
    deleteStart,
    deleteEnd - deleteStart,
    '$prefixBreak$preservedComments',
  );
}

/// Removes a middle entry (`0 < index < length - 1`) and its trailing `,`.
///
/// ```text
///   [a, b, c]          -->  [a, c]         (no comments: [b..c))
///   [a, # c0           -->  [a, # c0
///    b, # c1                 c]            (with comments: keep `# c0`, drop
///    c]                                     `b, # c1\n`)
/// ```
SourceEdit _removeMiddleFlowEntry(
  CstDocument document,
  CstFlowCollection collection,
  int index,
) {
  final previous = collection.entries[index - 1];
  final entry = collection.entries[index];
  final nextContent = collection.entries[index + 1].contentStart;
  final entryEnd = entry.end;

  if (document.commentsInRange(entryEnd, nextContent).isEmpty) {
    return SourceEdit(entry.contentStart, nextContent - entry.contentStart, '');
  }

  final commentBeforeEnd =
      _lastCommentBreakEnd(document, previous.end, entry.contentStart);
  final startsOwnLine = _startsOwnLine(document, entry.contentStart);
  final start = commentBeforeEnd ??
      (startsOwnLine
          ? document.lineStartOf(entry.contentStart)
          : entry.contentStart);

  final inlineComment = _sameLineCommentAfter(document, entryEnd, nextContent);
  final endAnchor = inlineComment?.span.end.offset ?? entryEnd;
  final deleteEnd = startsOwnLine || commentBeforeEnd != null
      ? document.lineBreakEndOf(endAnchor)
      : document.lineContentEndOf(endAnchor);
  return SourceEdit(start, deleteEnd - start, '');
}

/// Removes the final entry of a multi-entry flow collection.
///
/// ```text
///   1. Leading comment before last entry (keeps previous `,` as trailing):
///      [a,\n # above\n b]   -->  [a,\n # above\n]
///   2. Trailing comma on last entry (keeps previous `,`, drops `b,`):
///      [a,\n b,\n]          -->  [a,\n]
///   3. Standard last entry (drops preceding `,` and `b`):
///      [a, b]               -->  [a]
/// ```
SourceEdit _removeLastFlowEntry(
  CstDocument document,
  CstFlowCollection collection,
) {
  final entries = collection.entries;
  final previous = entries[entries.length - 2];
  final entry = entries.last;
  final hasTrailingComma = entry.comma != null;
  final from =
      hasTrailingComma ? previous.end : (previous.comma ?? previous.end);
  final entryContentEnd = hasTrailingComma
      ? entry.end
      : document.trimmedEnd(entry.contentStart, entry.end);
  final entryLineEnd = document.lineBreakEndOf(entryContentEnd);
  final closeOnLaterLine = document.lineStartOf(collection.closeStart) >
      document.lineStartOf(entryContentEnd);

  final commentBeforeEnd =
      _lastCommentBreakEnd(document, previous.end, entry.contentStart);
  if (commentBeforeEnd != null) {
    final deleteEnd = min(entryLineEnd, collection.closeStart);
    return SourceEdit(commentBeforeEnd, deleteEnd - commentBeforeEnd, '');
  }

  if (hasTrailingComma) {
    if (closeOnLaterLine && _startsOwnLine(document, entry.contentStart)) {
      final entryLineStart = document.lineStartOf(entry.contentStart);
      return SourceEdit(entryLineStart, entryLineEnd - entryLineStart, '');
    }
    final deleteEnd = closeOnLaterLine
        ? document.lineContentEndOf(entryContentEnd)
        : entryContentEnd;
    return SourceEdit(from, deleteEnd - from, '');
  }

  if (closeOnLaterLine) {
    if (_startsOwnLine(document, from)) {
      final fromLineStart = document.lineStartOf(from);
      return SourceEdit(fromLineStart, entryLineEnd - fromLineStart, '');
    }
    final deleteEnd = document.lineContentEndOf(entryContentEnd);
    return SourceEdit(from, deleteEnd - from, '');
  }

  return SourceEdit(from, collection.closeStart - from, '');
}
