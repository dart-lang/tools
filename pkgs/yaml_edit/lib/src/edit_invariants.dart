// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Debug-mode post-edit invariant verifier for [SourceEdit]s produced by
/// `YamlEditor`.
///
/// [checkEditInvariants] runs four independent checks against the initial and
/// updated [CstDocument]s:
/// 1. **Edit bounds** (`_checkEditBounds`): edits stay within the CST target
///    slot and pure insertions never overwrite existing syntax.
/// 2. **Layout preservation** (`_checkLayoutPreservation`): untouched siblings
///    and flow closing delimiters keep their line and column alignment.
/// 3. **Formatting hygiene** (`_checkFormattingHygiene`): trailing-comma style
///    is preserved, uniform line endings are not mixed, and no new
///    whitespace-only lines are introduced outside scalars.
/// 4. **Comment conservation** (`_checkCommentConservation`): every comment
///    outside the CST-derived droppable range survives verbatim with its
///    inline vs. own-line placement preserved.
library;

import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

import 'cst.dart';
import 'cst_helpers.dart';
import 'errors.dart';
import 'source_edit.dart';

/// The kind of mutation performed by `YamlEditor`.
enum EditOperation {
  /// Replacing an existing node or adding a new key to a mapping.
  update,

  /// Inserting a new entry into a sequence.
  insert,

  /// Removing an entry or the entire document.
  remove,
}

typedef _EditTarget = ({
  List<Object?> parentPath,
  CstNode? parent,
  int? index,
});

/// Verifies structural locality, layout/formatting preservation, and comment
/// conservation for [edit] against [initialDocument] and the already-parsed
/// [updatedDocument].
///
/// Intended to run inside `assert(...)` so release builds pay no runtime cost
/// and debug builds reuse the existing parse of [updatedDocument].
///
/// Throws an [AssertionError] with before/after YAML context if [edit]:
/// - escapes its CST target slot or rewrites bytes during a pure insertion;
/// - shifts an untouched sibling entry or flow closing delimiter off its line
///   or column;
/// - drops, corrupts, or changes the inline vs. own-line placement of a
///   comment outside the operation's CST-derived droppable range;
/// - breaks trailing-comma style when removing the last flow entry;
/// - mixes line endings in a uniform-EOL document; or
/// - introduces a non-empty whitespace-only line outside scalar content.
bool checkEditInvariants({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
}) {
  final target = _resolveTarget(initialDocument, operation, path);

  _checkEditBounds(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
    target: target,
  );

  _checkLayoutPreservation(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
    target: target,
  );

  _checkFormattingHygiene(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
    target: target,
  );

  _checkCommentConservation(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
    target: target,
  );

  return true;
}

_EditTarget _resolveTarget(
  CstDocument document,
  EditOperation operation,
  List<Object?> path,
) {
  if (operation != EditOperation.insert && path.isEmpty) {
    return (parentPath: const [], parent: null, index: null);
  }
  final parentPath = operation == EditOperation.insert
      ? path
      : path.sublist(0, path.length - 1);
  final parent = findNode(document, parentPath);
  if (parent == null || operation == EditOperation.insert) {
    return (parentPath: parentPath, parent: parent, index: null);
  }
  final step = path.last;
  final index = switch (parent) {
    CstBlockSeq(:final entries) => switch (step) {
        final int i when i >= 0 && i < entries.length => i,
        _ => null,
      },
    CstFlowSeq(:final entries) => switch (step) {
        final int i when i >= 0 && i < entries.length => i,
        _ => null,
      },
    CstBlockMap() || CstFlowMap() => findEntryIndex(parent, step),
    _ => null,
  };
  return (parentPath: parentPath, parent: parent, index: index);
}

void _checkEditBounds({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
  required _EditTarget target,
}) {
  final sourceLength = initialDocument.source.length;
  final editStart = edit.offset;
  final editEnd = edit.offset + edit.length;

  if (editEnd > sourceLength) {
    throw createAssertionError(
      'Edit range [$editStart, $editEnd) is out of bounds for source length '
      '$sourceLength.',
      initialDocument.source,
      updatedDocument.source,
    );
  }

  final bounds = _slotBounds(initialDocument, operation, path, target);
  if (bounds == null) return;

  if (editStart < bounds.start) {
    throw createAssertionError(
      'Edit start $editStart precedes CST slot start ${bounds.start} for '
      '$operation at $path.',
      initialDocument.source,
      updatedDocument.source,
    );
  }

  if (bounds.forbidSyntaxOverlap && edit.length > 0) {
    _assertNoNonCommentTokensInRange(
      initialDocument,
      updatedDocument,
      rangeStart: editStart,
      rangeEnd: editEnd,
      context: '$operation at $path',
    );
    // Pure insertions must not delete existing text; the only exception is a
    // block insertion extending past trailing comments to prevent a block
    // scalar from swallowing them.
    if (!bounds.allowTrailingTrivia ||
        initialDocument.commentsInRange(editStart, editEnd).isEmpty) {
      throw createAssertionError(
        'Pure insertion ($operation at $path) unexpectedly deleted '
        '${edit.length} bytes at offset $editStart.',
        initialDocument.source,
        updatedDocument.source,
      );
    }
  }

  if (editEnd > bounds.end) {
    if (!bounds.allowTrailingTrivia) {
      throw createAssertionError(
        'Edit end $editEnd exceeds CST slot end ${bounds.end} for '
        '$operation at $path.',
        initialDocument.source,
        updatedDocument.source,
      );
    }

    // Block mutations may extend past the slot end only over trailing blank
    // lines, whitespace, and comments (for dangling-comment cleanup or
    // preventing block-scalar swallowing), never over sibling syntax tokens.
    _assertNoNonCommentTokensInRange(
      initialDocument,
      updatedDocument,
      rangeStart: bounds.end,
      rangeEnd: editEnd,
      context: '$operation at $path past CST slot end ${bounds.end}',
    );
  }
}

void _assertNoNonCommentTokensInRange(
  CstDocument initialDocument,
  CstDocument updatedDocument, {
  required int rangeStart,
  required int rangeEnd,
  required String context,
}) {
  for (final token in initialDocument.tokens) {
    final tokenStart = token.span.start.offset;
    final tokenEnd = token.span.end.offset;
    if (tokenStart >= rangeEnd) break;
    if (tokenEnd <= rangeStart) continue;
    if (token.kind != YamlTokenKind.comment) {
      throw createAssertionError(
        'Edit crossed non-comment token ${token.kind} at offset $tokenStart '
        'during $context.',
        initialDocument.source,
        updatedDocument.source,
      );
    }
  }
}

({
  int start,
  int end,
  bool allowTrailingTrivia,
  bool forbidSyntaxOverlap,
})? _slotBounds(
  CstDocument document,
  EditOperation operation,
  List<Object?> path,
  _EditTarget target,
) {
  if (operation != EditOperation.insert && path.isEmpty) {
    if (operation == EditOperation.remove) {
      return (
        start: 0,
        end: document.source.length,
        allowTrailingTrivia: false,
        forbidSyntaxOverlap: false,
      );
    }
    final root = document.root;
    if (root == null) {
      return (
        start: 0,
        end: document.source.length,
        allowTrailingTrivia: false,
        forbidSyntaxOverlap: false,
      );
    }
    return (
      start: root.start,
      end: root.end,
      allowTrailingTrivia: true,
      forbidSyntaxOverlap: false,
    );
  }

  final parent = target.parent;
  if (parent == null) return null;

  if (operation == EditOperation.insert) {
    return switch (parent) {
      CstFlowCollection() => (
          start: parent.openEnd,
          end: parent.closeStart,
          allowTrailingTrivia: false,
          forbidSyntaxOverlap: true,
        ),
      CstBlockSeq() => (
          start: parent.contentStart,
          end: parent.end,
          allowTrailingTrivia: true,
          forbidSyntaxOverlap: true,
        ),
      _ => null,
    };
  }

  final index = target.index;
  switch (parent) {
    case CstFlowCollection():
      if (operation == EditOperation.update) {
        if (index != null) {
          final entry = parent.entries[index];
          return (
            start: entry.contentStart,
            end: entry.comma ?? parent.closeStart,
            allowTrailingTrivia: false,
            forbidSyntaxOverlap: false,
          );
        }
        // Adding a new key to a flow map must not overwrite existing tokens.
        return (
          start: parent.openEnd,
          end: parent.closeStart,
          allowTrailingTrivia: false,
          forbidSyntaxOverlap: true,
        );
      }
      if (index != null && parent.entries.length > 1) {
        final start = index == 0
            ? parent.openEnd
            : document.trimmedEnd(
                parent.entries[index - 1].contentStart,
                parent.entries[index - 1].value.end,
              );
        final end = index + 1 < parent.entries.length
            ? parent.entries[index + 1].contentStart
            : parent.closeStart;
        return (
          start: start,
          end: end,
          allowTrailingTrivia: false,
          forbidSyntaxOverlap: false,
        );
      }
      return (
        start: parent.openEnd,
        end: parent.closeStart,
        allowTrailingTrivia: false,
        forbidSyntaxOverlap: false,
      );

    case CstFlowPair():
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: false,
        forbidSyntaxOverlap: false,
      );

    case CstBlockSeq():
      if (index != null) {
        final entry = parent.entries[index];
        return (
          start: operation == EditOperation.update
              ? entry.dashStart + 1
              : entry.lineStart,
          end: entry.end,
          allowTrailingTrivia: true,
          forbidSyntaxOverlap: false,
        );
      }
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: true,
        forbidSyntaxOverlap: false,
      );

    case CstBlockMap():
      if (index != null) {
        final entry = parent.entries[index];
        return (
          start: operation == EditOperation.update
              ? (entry.colon != null ? entry.colon! + 1 : entry.key.end)
              : entry.lineStart,
          end: entry.end,
          allowTrailingTrivia: true,
          forbidSyntaxOverlap: false,
        );
      }
      // Adding a new key to a block map must not overwrite existing tokens.
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: true,
        forbidSyntaxOverlap: true,
      );

    case CstScalar() || CstAlias() || CstEmpty():
      return null;
  }
}

bool _startsOwnLine(CstDocument document, int offset) =>
    document.isWhitespaceRange(document.lineStartOf(offset), offset);

void _checkLayoutPreservation({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
  required _EditTarget target,
}) {
  final parent = target.parent;
  if (parent == null) return;

  final editStart = edit.offset;
  final editOldEnd = edit.offset + edit.length;
  final delta = edit.replacement.length - edit.length;
  final targetIndex = target.index;

  void checkLandmark(int oldOffset, String label) {
    if (oldOffset > editStart && oldOffset < editOldEnd) return;
    if (!_startsOwnLine(initialDocument, oldOffset)) return;
    final newOffset = oldOffset < editStart ? oldOffset : oldOffset + delta;
    if (!_startsOwnLine(updatedDocument, newOffset) ||
        updatedDocument.columnOf(newOffset) !=
            initialDocument.columnOf(oldOffset)) {
      throw createAssertionError(
        '$label at offset $oldOffset shifted from own-line column '
        '${initialDocument.columnOf(oldOffset)} after $operation at $path.',
        initialDocument.source,
        updatedDocument.source,
      );
    }
  }

  switch (parent) {
    case CstBlockSeq():
      for (var i = 0; i < parent.entries.length; i++) {
        if (i == targetIndex) continue;
        // Removing entry 0 of a compact sequence intentionally shifts entry 1
        // onto entry 0's compact `- ` line.
        if (operation == EditOperation.remove &&
            targetIndex == 0 &&
            parent.isCompact &&
            i == 1) {
          continue;
        }
        checkLandmark(parent.entries[i].dashStart, 'Sibling sequence entry $i');
      }

    case CstBlockMap():
      for (var i = 0; i < parent.entries.length; i++) {
        if (i == targetIndex) continue;
        if (operation == EditOperation.remove &&
            targetIndex == 0 &&
            parent.isCompact &&
            i == 1) {
          continue;
        }
        checkLandmark(parent.entries[i].keyStart, 'Sibling mapping entry $i');
      }

    case CstFlowCollection():
      final isInsertOrAdd = operation == EditOperation.insert ||
          (operation == EditOperation.update && targetIndex == null);
      final removedInlineEntry = operation == EditOperation.remove &&
          targetIndex != null &&
          !_startsOwnLine(
            initialDocument,
            parent.entries[targetIndex].contentStart,
          );
      for (var i = 0; i < parent.entries.length; i++) {
        if (i == targetIndex) continue;
        final anchor = parent.entries[i].contentStart;
        // Inserting before a flow entry prepends `newItem, ` on that entry's
        // line, shifting the entry right on its line.
        if (isInsertOrAdd && anchor == editStart) continue;
        // Removing an entry that sat inline after `[`/`{` or a preceding entry
        // lets the next entry slide into that inline slot.
        if (removedInlineEntry && i == targetIndex + 1) continue;
        checkLandmark(anchor, 'Sibling flow entry $i');
      }
      final keepsCollection =
          !(operation == EditOperation.remove && parent.entries.length == 1);
      final appendsWithoutTrailingComma = isInsertOrAdd &&
          editStart == parent.closeStart &&
          (parent.entries.isEmpty || parent.entries.last.comma == null);
      if (keepsCollection && !appendsWithoutTrailingComma) {
        checkLandmark(parent.closeStart, 'Flow closing delimiter');
      }

    case CstFlowPair() || CstScalar() || CstAlias() || CstEmpty():
      break;
  }
}

void _checkFormattingHygiene({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
  required _EditTarget target,
}) {
  // 1. Line-ending consistency on uniform-EOL documents.
  final initial = initialDocument.source;
  final hasCrlf = initial.contains('\r\n');
  final hasBareLf = _containsBareLf(initial);
  if (hasCrlf && !hasBareLf) {
    if (_containsBareLf(edit.replacement)) {
      throw createAssertionError(
        'Edit introduced LF line break in a CRLF document for $operation at '
        '$path.',
        initial,
        updatedDocument.source,
      );
    }
  } else if (hasBareLf && !hasCrlf) {
    if (edit.replacement.contains('\r\n')) {
      throw createAssertionError(
        'Edit introduced CRLF line break in an LF document for $operation at '
        '$path.',
        initial,
        updatedDocument.source,
      );
    }
  }

  // 2. Trailing-comma preservation when removing the last entry of a
  // multi-entry flow collection written in trailing-comma style.
  if (operation == EditOperation.remove) {
    final parent = target.parent;
    if (parent is CstFlowCollection &&
        parent.entries.length > 1 &&
        parent.entries.last.comma != null &&
        target.index == parent.entries.length - 1) {
      final updatedParent = findNode(updatedDocument, target.parentPath);
      if (updatedParent is CstFlowCollection &&
          updatedParent.entries.isNotEmpty &&
          updatedParent.entries.last.comma == null) {
        throw createAssertionError(
          'Removing the last entry of a trailing-comma flow collection at '
          '$path dropped the trailing comma.',
          initial,
          updatedDocument.source,
        );
      }
    }
  }

  // 3. No newly introduced non-empty whitespace-only lines outside scalars.
  final editStart = edit.offset;
  final editNewEnd = editStart + edit.replacement.length;
  final delta = edit.replacement.length - edit.length;
  final updated = updatedDocument.source;

  bool wasPreexistingWhitespaceLine(int start, int end) {
    if (end <= editStart) {
      return initialDocument.lineStartOf(start) == start &&
          initialDocument.lineContentEndOf(start) == end &&
          initialDocument.isWhitespaceRange(start, end) &&
          !_isInsideScalar(initialDocument, start, end);
    }
    if (start >= editNewEnd) {
      final oldStart = start - delta;
      final oldEnd = end - delta;
      return initialDocument.lineStartOf(oldStart) == oldStart &&
          initialDocument.lineContentEndOf(oldStart) == oldEnd &&
          initialDocument.isWhitespaceRange(oldStart, oldEnd) &&
          !_isInsideScalar(initialDocument, oldStart, oldEnd);
    }
    return false;
  }

  var cursor = updatedDocument.lineStartOf(editStart);
  final scanEnd = updatedDocument.lineBreakEndOf(editNewEnd);
  while (cursor < scanEnd) {
    final contentEnd = updatedDocument.lineContentEndOf(cursor);
    final breakEnd = updatedDocument.lineBreakEndOf(cursor);
    if (contentEnd > cursor &&
        updatedDocument.isWhitespaceRange(cursor, contentEnd) &&
        !_isInsideScalar(updatedDocument, cursor, contentEnd) &&
        !wasPreexistingWhitespaceLine(cursor, contentEnd)) {
      throw createAssertionError(
        'Edit introduced a whitespace-only line at offset $cursor for '
        '$operation at $path.',
        initial,
        updated,
      );
    }
    if (breakEnd <= cursor) break;
    cursor = breakEnd;
  }
}

bool _containsBareLf(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A &&
        (i == 0 || text.codeUnitAt(i - 1) != 0x0D)) {
      return true;
    }
  }
  return false;
}

bool _isInsideScalar(CstDocument document, int start, int end) {
  final root = document.root;
  if (root == null) return false;
  final stack = <CstNode>[root];
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (end <= node.start || start >= node.end) continue;
    switch (node) {
      case CstScalar():
        final scalarEnd = node.value.style == ScalarStyle.PLAIN
            ? document.trimmedEnd(node.contentStart, node.end)
            : node.end;
        if (start >= node.contentStart && end <= scalarEnd) return true;
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
      case CstAlias() || CstEmpty():
        break;
    }
  }
  return false;
}

void _checkCommentConservation({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
  required _EditTarget target,
}) {
  if (initialDocument.comments.isEmpty) return;

  final editStart = edit.offset;
  final editOldEnd = edit.offset + edit.length;
  final editNewEnd = editStart + edit.replacement.length;
  final delta = edit.replacement.length - edit.length;
  final droppable =
      _droppableCommentRange(initialDocument, operation, path, target);

  // Removing entry 0 of a compact block collection (`- - 0\n  # c\n  - 1`)
  // can legitimately move an own-line comment right after entry 0 onto the
  // outer indicator's line (`-   # c`).
  final compactLiftRange =
      operation == EditOperation.remove && target.index == 0
          ? switch (target.parent) {
              CstBlockSeq(isCompact: true, :final entries)
                  when entries.length > 1 =>
                (start: entries[0].end, end: entries[1].dashStart),
              CstBlockMap(isCompact: true, :final entries)
                  when entries.length > 1 =>
                (start: entries[0].end, end: entries[1].keyStart),
              _ => null,
            }
          : null;

  final updatedCommentsByStart = <int, YamlToken>{
    for (final comment in updatedDocument.comments)
      comment.span.start.offset: comment,
  };

  final updatedInReplacement = <YamlToken>[
    for (final comment in updatedDocument.comments)
      if (comment.span.start.offset >= editStart &&
          comment.span.start.offset < editNewEnd)
        comment,
  ];
  var replacementCursor = 0;

  void checkPlacement(YamlToken before, YamlToken after, String text) {
    final beforeStart = before.span.start.offset;
    final beforeEnd = before.span.end.offset;
    final wasOwnLine = _startsOwnLine(initialDocument, beforeStart);
    final isOwnLine = _startsOwnLine(updatedDocument, after.span.start.offset);
    final allowedLift = wasOwnLine &&
        compactLiftRange != null &&
        beforeStart >= compactLiftRange.start &&
        beforeEnd <= compactLiftRange.end;
    if (wasOwnLine != isOwnLine && !allowedLift) {
      throw createAssertionError(
        'Comment "$text" at offset $beforeStart changed '
        'placement (${wasOwnLine ? 'own-line' : 'inline'} -> '
        '${isOwnLine ? 'own-line' : 'inline'}).',
        initialDocument.source,
        updatedDocument.source,
      );
    }
  }

  for (final comment in initialDocument.comments) {
    final start = comment.span.start.offset;
    final end = comment.span.end.offset;
    final text = comment.span.text.trimRight();

    if (end <= editStart) {
      final after = updatedCommentsByStart[start];
      if (after == null || after.span.text.trimRight() != text) {
        throw createAssertionError(
          'Comment "$text" before edit at offset $start was lost or modified.',
          initialDocument.source,
          updatedDocument.source,
        );
      }
      continue;
    }

    if (start >= editOldEnd) {
      final expectedStart = start + delta;
      final after = updatedCommentsByStart[expectedStart];
      if (after == null || after.span.text.trimRight() != text) {
        throw createAssertionError(
          'Comment "$text" after edit at offset $start was lost or modified.',
          initialDocument.source,
          updatedDocument.source,
        );
      }
      checkPlacement(comment, after, text);
      continue;
    }

    if (droppable != null && start >= droppable.start && end <= droppable.end) {
      continue;
    }

    YamlToken? matched;
    while (replacementCursor < updatedInReplacement.length) {
      final candidate = updatedInReplacement[replacementCursor++];
      if (candidate.span.text.trimRight() == text) {
        matched = candidate;
        break;
      }
    }
    if (matched == null) {
      throw createAssertionError(
        'Comment "$text" at offset $start was unintentionally removed.',
        initialDocument.source,
        updatedDocument.source,
      );
    }
    checkPlacement(comment, matched, text);
  }
}

/// Computes the source range within [document] whose comments are allowed to be
/// dropped by [operation] at [path], derived purely from the CST.
///
/// Returns `null` when no comments may be dropped (for example, list
/// insertions, adding a new mapping key, or updating a property-less scalar).
({int start, int end})? _droppableCommentRange(
  CstDocument document,
  EditOperation operation,
  List<Object?> path,
  _EditTarget target,
) {
  switch (operation) {
    case EditOperation.insert:
      return null;

    case EditOperation.update:
      if (path.isEmpty) {
        final root = document.root;
        if (root == null) return (start: 0, end: document.source.length);
        return _droppableForReplacedNode(root);
      }
      final oldNode = findNode(document, path);
      if (oldNode == null) return null;
      return _droppableForReplacedNode(oldNode);

    case EditOperation.remove:
      if (path.isEmpty) return (start: 0, end: document.source.length);
      final parent = target.parent;
      final index = target.index;
      switch (parent) {
        case CstBlockSeq():
          if (index == null) return null;
          final entry = parent.entries[index];
          final end =
              (parent.entries.length > 1 && !(index == 0 && parent.isCompact))
                  ? document.extendPastIndentedCommentsAndBlankLines(
                      entry.end,
                      document.columnOf(parent.entries.first.dashStart),
                    )
                  : entry.end;
          return (start: entry.lineStart, end: end);

        case CstBlockMap():
          if (index == null) return null;
          final entry = parent.entries[index];
          final end =
              (parent.entries.length > 1 && !(index == 0 && parent.isCompact))
                  ? document.extendPastIndentedCommentsAndBlankLines(
                      entry.end,
                      document.columnOf(parent.entries.first.keyStart),
                    )
                  : entry.end;
          return (start: entry.lineStart, end: end);

        case CstFlowCollection():
          if (index == null) return null;
          if (parent.entries.length == 1) {
            return (start: parent.openEnd, end: parent.closeStart);
          }
          final entry = parent.entries[index];
          final nextBound = index + 1 < parent.entries.length
              ? parent.entries[index + 1].contentStart
              : parent.closeStart;
          final lineEnd = document.lineBreakEndOf(entry.end);
          final boundedLineEnd = lineEnd < nextBound ? lineEnd : nextBound;
          final dropEnd =
              boundedLineEnd > entry.end ? boundedLineEnd : entry.end;
          return (start: entry.contentStart, end: dropEnd);

        case CstFlowPair():
          return (start: parent.contentStart, end: parent.end);

        default:
          return null;
      }
  }
}

({int start, int end})? _droppableForReplacedNode(CstNode node) =>
    switch (node) {
      CstScalar() ||
      CstAlias() ||
      CstEmpty() =>
        node.hasProperties ? (start: node.start, end: node.contentStart) : null,
      CstBlockSeq() ||
      CstBlockMap() ||
      CstFlowCollection() ||
      CstFlowPair() =>
        (start: node.start, end: node.contentEnd),
    };
