// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Debug-mode structural locality and comment-conservation checks for
/// [SourceEdit]s produced by `YamlEditor`.
library;

import 'package:yaml/tokens.dart';

import 'cst.dart';
import 'cst_mutations.dart';
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

/// Verifies structural locality and comment conservation for [edit] against
/// [initialDocument] and the already-parsed [updatedDocument].
///
/// Intended to run inside `assert(...)` so release builds pay no runtime cost
/// and debug builds reuse the existing parse of [updatedDocument].
///
/// Throws an [AssertionError] with before/after YAML context if [edit] escapes
/// its CST target slot or drops/corrupts a comment outside the operation's
/// CST-derived droppable range.
bool checkEditInvariants({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
}) {
  _checkEditBounds(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
  );

  _checkCommentConservation(
    initialDocument: initialDocument,
    updatedDocument: updatedDocument,
    edit: edit,
    operation: operation,
    path: path,
  );

  return true;
}

void _checkEditBounds({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
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

  final bounds = _slotBounds(initialDocument, operation, path);
  if (bounds == null) return;

  if (editStart < bounds.start) {
    throw createAssertionError(
      'Edit start $editStart precedes CST slot start ${bounds.start} for '
      '$operation at $path.',
      initialDocument.source,
      updatedDocument.source,
    );
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
    for (final token in initialDocument.tokens) {
      final tokenStart = token.span.start.offset;
      final tokenEnd = token.span.end.offset;
      if (tokenStart >= editEnd) break;
      if (tokenEnd <= bounds.end) continue;
      if (token.kind != YamlTokenKind.comment) {
        throw createAssertionError(
          'Edit end $editEnd crossed non-comment token ${token.kind} at '
          'offset $tokenStart past CST slot end ${bounds.end} for '
          '$operation at $path.',
          initialDocument.source,
          updatedDocument.source,
        );
      }
    }
  }
}

({int start, int end, bool allowTrailingTrivia})? _slotBounds(
  CstDocument document,
  EditOperation operation,
  List<Object?> path,
) {
  if (operation != EditOperation.insert && path.isEmpty) {
    if (operation == EditOperation.remove) {
      return (
        start: 0,
        end: document.source.length,
        allowTrailingTrivia: false
      );
    }
    final root = document.root;
    if (root == null) {
      return (
        start: 0,
        end: document.source.length,
        allowTrailingTrivia: false
      );
    }
    return (start: root.start, end: root.end, allowTrailingTrivia: true);
  }

  final parentPath = operation == EditOperation.insert
      ? path
      : path.sublist(0, path.length - 1);
  final parent = findNode(document, parentPath);
  if (parent == null) return null;

  if (operation == EditOperation.insert) {
    return switch (parent) {
      CstFlowCollection() => (
          start: parent.openEnd,
          end: parent.closeStart,
          allowTrailingTrivia: false,
        ),
      CstBlockSeq() => (
          start: parent.contentStart,
          end: parent.end,
          allowTrailingTrivia: true,
        ),
      _ => null,
    };
  }

  final step = path.last;
  switch (parent) {
    case CstFlowCollection():
      if (operation == EditOperation.update) {
        final index = parent is CstFlowSeq
            ? (step is int ? step : null)
            : findEntryIndex(parent, step);
        if (index != null && index >= 0 && index < parent.entries.length) {
          final entry = parent.entries[index];
          return (
            start: entry.contentStart,
            end: entry.comma ?? parent.closeStart,
            allowTrailingTrivia: false,
          );
        }
      }
      return (
        start: parent.openEnd,
        end: parent.closeStart,
        allowTrailingTrivia: false,
      );

    case CstFlowPair():
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: false,
      );

    case CstBlockSeq():
      if (step is int && step >= 0 && step < parent.entries.length) {
        final entry = parent.entries[step];
        return (
          start: entry.lineStart,
          end: entry.end,
          allowTrailingTrivia: true,
        );
      }
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: true,
      );

    case CstBlockMap():
      final index = findEntryIndex(parent, step);
      if (index != null) {
        final entry = parent.entries[index];
        return (
          start: entry.lineStart,
          end: entry.end,
          allowTrailingTrivia: true,
        );
      }
      return (
        start: parent.contentStart,
        end: parent.end,
        allowTrailingTrivia: true,
      );

    case CstScalar() || CstAlias() || CstEmpty():
      return null;
  }
}

void _checkCommentConservation({
  required CstDocument initialDocument,
  required CstDocument updatedDocument,
  required SourceEdit edit,
  required EditOperation operation,
  required List<Object?> path,
}) {
  if (initialDocument.comments.isEmpty) return;

  final editStart = edit.offset;
  final editOldEnd = edit.offset + edit.length;
  final editNewEnd = editStart + edit.replacement.length;
  final delta = edit.replacement.length - edit.length;
  final droppable = _droppableCommentRange(initialDocument, operation, path);

  final updatedCommentsByStart = <int, YamlToken>{
    for (final comment in updatedDocument.comments)
      comment.span.start.offset: comment,
  };

  final updatedInReplacement = <String>[
    for (final comment in updatedDocument.comments)
      if (comment.span.start.offset >= editStart &&
          comment.span.start.offset < editNewEnd)
        comment.span.text.trimRight(),
  ];
  var replacementCursor = 0;

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
      continue;
    }

    if (droppable != null && start >= droppable.start && end <= droppable.end) {
      continue;
    }

    var matched = false;
    while (replacementCursor < updatedInReplacement.length) {
      if (updatedInReplacement[replacementCursor++] == text) {
        matched = true;
        break;
      }
    }
    if (!matched) {
      throw createAssertionError(
        'Comment "$text" at offset $start was unintentionally removed.',
        initialDocument.source,
        updatedDocument.source,
      );
    }
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
      final parent = findNode(document, path.sublist(0, path.length - 1));
      final step = path.last;
      switch (parent) {
        case CstBlockSeq():
          final index = step as int;
          final entry = parent.entries[index];
          final end =
              (parent.entries.length > 1 && !(index == 0 && parent.isCompact))
                  ? _extendPastIndentedComments(
                      document,
                      entry.end,
                      document.columnOf(parent.entries.first.dashStart),
                    )
                  : entry.end;
          return (start: entry.lineStart, end: end);

        case CstBlockMap():
          final index = findEntryIndex(parent, step);
          if (index == null) return null;
          final entry = parent.entries[index];
          final end =
              (parent.entries.length > 1 && !(index == 0 && parent.isCompact))
                  ? _extendPastIndentedComments(
                      document,
                      entry.end,
                      document.columnOf(parent.entries.first.keyStart),
                    )
                  : entry.end;
          return (start: entry.lineStart, end: end);

        case CstFlowCollection():
          final index =
              parent is CstFlowSeq ? step as int : findEntryIndex(parent, step);
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

int _extendPastIndentedComments(
  CstDocument document,
  int startOffset,
  int collectionIndent,
) {
  final source = document.source;
  var endOffset = startOffset;
  var probe = startOffset;

  while (probe < source.length) {
    final lineStart = document.lineStartOf(probe);
    if (probe != lineStart) break;

    final lineContentEnd = document.lineContentEndOf(probe);
    final lineBreakEnd = document.lineBreakEndOf(probe);

    final comment = document.commentInRange(lineStart, lineContentEnd);
    if (comment != null) {
      final commentStart = comment.span.start.offset;
      if (_isHorizontalWhitespace(source, lineStart, commentStart) &&
          commentStart - lineStart > collectionIndent) {
        endOffset = lineBreakEnd;
        probe = lineBreakEnd;
        continue;
      }
      break;
    }

    if (_isHorizontalWhitespace(source, lineStart, lineContentEnd)) {
      endOffset = lineBreakEnd;
      probe = lineBreakEnd;
      continue;
    }

    break;
  }

  return endOffset;
}

bool _isHorizontalWhitespace(String source, int start, int end) {
  for (var i = start; i < end; i++) {
    final char = source.codeUnitAt(i);
    if (char != 0x20 && char != 0x09) return false;
  }
  return true;
}
