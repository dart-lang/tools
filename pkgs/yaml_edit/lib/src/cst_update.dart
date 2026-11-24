// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cst_mutations.dart';

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
  final (:edit, :trailingBlockScalarBodyIndent) =
      _buildUpdate(document, path, value);
  if (trailingBlockScalarBodyIndent != null) {
    final entryColumn = _entryColumnForUpdate(document, path);
    return _preventBlockScalarSwallowing(
      document,
      edit,
      bodyIndent: trailingBlockScalarBodyIndent,
      targetColumn: min(entryColumn, trailingBlockScalarBodyIndent - 1),
    );
  }
  return edit;
}

int _entryColumnForUpdate(CstDocument document, List<Object?> path) {
  if (path.isEmpty) return 0;
  final parent = findNode(document, path.take(path.length - 1));
  final step = path.last;
  return switch (parent) {
    CstBlockSeq()
        when step is int && step >= 0 && step < parent.entries.length =>
      document.columnOf(parent.entries[step].dashStart),
    CstBlockMap() => switch (findEntryIndex(parent, step)) {
        final index? => document.columnOf(parent.entries[index].keyStart),
        null => document.columnOf(parent.entries.first.keyStart),
      },
    _ => 0,
  };
}

/// Adjusts [edit] to prevent an emitted block scalar with [bodyIndent] from
/// swallowing subsequent over-indented comments or whitespace-only lines
/// (addressing H2RW_0).
///
/// Blank lines of any indentation do not terminate a YAML block scalar, so this
/// scans across blank lines until a terminating line (a comment at column less
/// than [bodyIndent] or a content line) is reached. If no hazardous line is
/// found, [edit] is returned unchanged. Over-indented comments are re-indented
/// to [targetColumn] (strictly less than [bodyIndent]), terminating the block
/// scalar while keeping comments aligned with the enclosing entry.
SourceEdit _preventBlockScalarSwallowing(
  CstDocument document,
  SourceEdit edit, {
  required int bodyIndent,
  required int targetColumn,
}) {
  final endOffset = edit.offset + edit.length;
  var probe = endOffset;

  // When [edit] ends mid-line (for example, replacing a scalar in place), step
  // past that line's own terminating line break. When [edit] already ends at a
  // line start (such as a whole-line insertion), leave the line at [endOffset]
  // intact so we inspect it as the first following line.
  final atLineStart = probe == document.lineStartOf(probe);
  if (!atLineStart) {
    final breakLength = document.lineBreakLengthAt(probe);
    if (breakLength > 0) {
      probe += breakLength;
    }
  }

  var sawHazard = false;
  final buffer = StringBuffer();
  final source = document.source;
  final indentPrefix = ' ' * targetColumn;

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
        sawHazard = true;
        final commentText =
            source.substring(comment.span.start.offset, lineContentEnd);
        buffer.write('$indentPrefix$commentText$lineBreak');
        probe = lineBreakEnd;
        // Re-indenting this comment to `targetColumn < bodyIndent` terminates
        // the block scalar, so subsequent lines are safe.
        break;
      }
      // A comment indented less than [bodyIndent] already terminates the block
      // scalar.
      break;
    }

    if (document.isWhitespaceRange(lineStart, lineContentEnd)) {
      final spacesCount = lineContentEnd - lineStart;
      if (document.hasTabInRange(lineStart, lineContentEnd) ||
          spacesCount >= bodyIndent) {
        sawHazard = true;
        buffer.write(lineBreak);
      } else {
        buffer.write(source.substring(lineStart, lineBreakEnd));
      }
      probe = lineBreakEnd;
      continue;
    }

    break;
  }

  if (!sawHazard) return edit;

  final extraLength = probe - endOffset;
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

_MutationEdit _buildUpdate(
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
      return (
        edit: _replaceFlowValue(document, parent.entries[step].value, value),
        trailingBlockScalarBodyIndent: null,
      );

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
        return (
          edit: _appendFlowMapEntry(document, parent, step, value),
          trailingBlockScalarBodyIndent: null,
        );
      }
      return (
        edit: _replaceFlowMapValue(
            document, parent, parent.entries[index], value),
        trailingBlockScalarBodyIndent: null,
      );

    case CstFlowPair():
      if (findEntryIndex(parent, step) == null) {
        final keyText = yamlEncodeFlow(wrapAsYamlNode(step));
        final valueText = yamlEncodeFlow(value);
        final trimmed = document.trimmedEnd(parent.contentStart, parent.end);
        final pairEnd = document.hasLineBreakInRange(trimmed, parent.end)
            ? trimmed
            : parent.end;
        final existingText =
            document.source.substring(parent.contentStart, pairEnd);
        final replacement = '{$existingText, $keyText: $valueText}';
        return (
          edit: SourceEdit(
              parent.contentStart, pairEnd - parent.contentStart, replacement),
          trailingBlockScalarBodyIndent: null,
        );
      }
      return (
        edit: _replaceFlowValue(document, parent.pairValue, value),
        trailingBlockScalarBodyIndent: null,
      );

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

/// Appends [lineEnding] to [replacement] when the replaced range ends just
/// past a line break in [document], preventing the next line from joining onto
/// the replacement.
String _preserveTrailingBreak(
  CstDocument document,
  int replaceEnd,
  String replacement,
  String lineEnding,
) {
  if (replaceEnd > 0 &&
      document.hasLineBreakBefore(replaceEnd) &&
      !replacement.endsWith(lineEnding)) {
    return '$replacement$lineEnding';
  }
  return replacement;
}

_MutationEdit _replaceRoot(
  CstDocument document,
  LayoutStyle style,
  YamlNode value,
) {
  final encoded = yamlEncodeBlockWithInfo(value, 0, style.lineEnding);
  final root = document.root;
  if (root == null) {
    // The document holds no node, only blank space and comments. Replacing the
    // root of such a document replaces the document.
    return (
      edit: SourceEdit(0, document.source.length, encoded.text),
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }
  final isBlockScalar =
      value is YamlScalar && encoded.trailingBlockScalarBodyIndent != null;
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    root,
    newIsBlockScalar: isBlockScalar,
  );
  final textToInsert = _preserveTrailingBreak(
    document,
    replaceEnd,
    _attachCommentToReplacement(
      encoded.text,
      commentToAttach,
      style.lineEnding,
      isBlockScalar: isBlockScalar,
    ),
    style.lineEnding,
  );

  return (
    edit: SourceEdit(root.start, replaceEnd - root.start, textToInsert),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}

/// Replaces the value of a block sequence entry.
///
/// The region replaced starts just past the `-` rather than at the value, so
/// that the space between them can be rewritten: going from `- 1` to a nested
/// block collection needs different spacing than going the other way. When a
/// comment sits between the `-` and the value there is nothing to rewrite, so
/// only the value itself is replaced.
_MutationEdit _replaceBlockSeqValue(
  CstDocument document,
  LayoutStyle style,
  CstBlockSeqEntry entry,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return (
      edit: SourceEdit(entry.value.start, 0, ''),
      trailingBlockScalarBodyIndent: null,
    );
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
  final encoded = encodeAfterDash(value, style, dashColumn: dashColumn);
  var encodedText = encoded.text;
  if (entry.value is CstBlockSeq || entry.value is CstBlockMap) {
    final hasTrailingComment =
        !document.hasLineBreakBefore(entry.value.contentEnd) &&
            document.commentInRange(
                  entry.value.contentEnd,
                  document.lineBreakEndOf(entry.value.contentEnd),
                ) !=
                null;
    if (!hasTrailingComment &&
        encodedText.isNotEmpty &&
        !encodedText.endsWith(style.lineEnding)) {
      encodedText += style.lineEnding;
    }
  }

  final isBlockScalar =
      value is YamlScalar && encoded.trailingBlockScalarBodyIndent != null;
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    entry.value,
    newIsBlockScalar: isBlockScalar,
  );
  final textToInsert = _preserveTrailingBreak(
    document,
    replaceEnd,
    _attachCommentToReplacement(
      ' $encodedText',
      commentToAttach,
      style.lineEnding,
      isBlockScalar: isBlockScalar,
    ),
    style.lineEnding,
  );

  return (
    edit: SourceEdit(
      entry.dashStart + 1,
      replaceEnd - entry.dashStart - 1,
      textToInsert,
    ),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}

/// Replaces the value of a block mapping entry, rewriting the space after the
/// `:` when it holds no comment.
_MutationEdit _replaceBlockMapValue(
  CstDocument document,
  LayoutStyle style,
  CstBlockMapEntry entry,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return (
      edit: SourceEdit(entry.value.start, 0, ''),
      trailingBlockScalarBodyIndent: null,
    );
  }
  if (entry.value.hasProperties && deepEquals(entry.value.value, value)) {
    return _replaceInPlace(document, style, entry.value, value);
  }
  final keyColumn = document.columnOf(entry.keyStart);
  final encoded = encodeValue(value, style, indicatorColumn: keyColumn);
  final isBlockScalar =
      value is YamlScalar && encoded.trailingBlockScalarBodyIndent != null;

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

    return (
      edit: SourceEdit(
          entry.value.start, replaceEnd - entry.value.start, fullText),
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }

  if (entry.hasSeparatorComment) {
    return _replaceInPlace(document, style, entry.value, value);
  }

  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    entry.value,
    newIsBlockScalar: isBlockScalar,
  );

  final joiner = encoded.ownLine ? style.lineEnding : ' ';
  final fullReplacement = _preserveTrailingBreak(
    document,
    replaceEnd,
    _attachCommentToReplacement(
      '$joiner${encoded.text}',
      commentToAttach,
      style.lineEnding,
      isBlockScalar: isBlockScalar,
    ),
    style.lineEnding,
  );
  return (
    edit: SourceEdit(
      colon + 1,
      replaceEnd - colon - 1,
      fullReplacement,
    ),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}

/// Replaces a node without touching anything around it.
///
/// Used when the space before the value cannot be rewritten because it holds a
/// comment. The replacement is written at the column the old value occupied.
_MutationEdit _replaceInPlace(
  CstDocument document,
  LayoutStyle style,
  CstNode old,
  YamlNode value,
) {
  if (old is CstEmpty && value.value == null) {
    return (
      edit: SourceEdit(old.start, 0, ''),
      trailingBlockScalarBodyIndent: null,
    );
  }
  final isCollection = value is YamlList || value is YamlMap;
  final column = switch (old) {
    CstBlockSeq() => document.columnOf(old.entries.first.dashStart),
    CstBlockMap() => document.columnOf(old.entries.first.keyStart),
    _ => document.columnOf(old.start),
  };
  final lineStart = document.lineStartOf(old.start);
  final startsOwnLine = document.startsOwnLine(old.start);
  final encoded = yamlEncodeBlockWithInfo(value, column, style.lineEnding);
  var text = encoded.text;
  final hasLeadingIndent = isCollection && isBlockNode(value);
  if (startsOwnLine && !hasLeadingIndent) {
    text = '${' ' * column}$text';
  } else if (!startsOwnLine && hasLeadingIndent) {
    text = text.substring(column);
  }

  final isBlockScalar =
      value is YamlScalar && encoded.trailingBlockScalarBodyIndent != null;
  final (:commentToAttach, :replaceEnd) = _extractNodeComment(
    document,
    old,
    newIsBlockScalar: isBlockScalar,
  );
  text = _preserveTrailingBreak(
    document,
    replaceEnd,
    _attachCommentToReplacement(
      text,
      commentToAttach,
      style.lineEnding,
      isBlockScalar: isBlockScalar,
    ),
    style.lineEnding,
  );

  final startOffset =
      startsOwnLine ? lineStart : (isCollection ? old.start : old.contentStart);
  return (
    edit: SourceEdit(startOffset, replaceEnd - startOffset, text),
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}

/// Replaces a value inside a flow collection, where everything stays on one
/// line and only flow syntax is allowed.
SourceEdit _replaceFlowValue(
  CstDocument document,
  CstNode old,
  YamlNode value,
) {
  if (old is CstEmpty && value.value == null) {
    return SourceEdit(old.start, 0, '');
  }
  final startOffset = (old.hasProperties && deepEquals(old.value, value))
      ? old.contentStart
      : old.start;
  final trimmed = document.trimmedEnd(startOffset, old.end);
  final endOffset =
      document.hasLineBreakInRange(trimmed, old.end) ? trimmed : old.end;
  return SourceEdit(
      startOffset, endOffset - startOffset, yamlEncodeFlow(value));
}

/// Replaces the value of a flow mapping entry, writing a `:` if the entry was
/// a bare key such as the `a` in `{a, b}`.
SourceEdit _replaceFlowMapValue(
  CstDocument document,
  CstFlowMap map,
  CstFlowEntry entry,
  YamlNode value,
) {
  if (entry.value is CstEmpty && value.value == null) {
    return SourceEdit(entry.value.start, 0, '');
  }
  final text = yamlEncodeFlow(value);
  if (entry.colon == null) {
    final atOwnLineClose = entry.value.start == map.closeStart &&
        document.startsOwnLine(map.closeStart);
    final suffix = atOwnLineClose
        ? '${document.lineEnding}${' ' * document.columnOf(map.closeStart)}'
        : '';
    return SourceEdit(entry.value.start, entry.value.end - entry.value.start,
        ': $text$suffix');
  }
  if (entry.value is CstEmpty) {
    final trailingEnd = entry.comma ?? map.closeStart;
    if (document.commentsInRange(entry.value.start, trailingEnd).isEmpty &&
        !document.hasLineBreakInRange(entry.value.start, trailingEnd)) {
      return SourceEdit(
          entry.value.start, trailingEnd - entry.value.start, ' $text');
    }
    return SourceEdit(entry.value.start, 0, ' $text');
  }
  return _replaceFlowValue(document, entry.value, value);
}
