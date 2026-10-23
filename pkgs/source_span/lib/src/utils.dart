// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'charcode.dart';
import 'file.dart';
import 'location.dart';
import 'span.dart';
import 'span_with_context.dart';

/// Returns the minimum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
T min<T extends Comparable<T>>(T obj1, T obj2) =>
    obj1.compareTo(obj2) > 0 ? obj2 : obj1;

/// Returns the maximum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
T max<T extends Comparable<T>>(T obj1, T obj2) =>
    obj1.compareTo(obj2) > 0 ? obj1 : obj2;

/// Returns whether all elements of [iter] are the same value, according to
/// `==`.
bool isAllTheSame(Iterable<Object?> iter) {
  if (iter.isEmpty) return true;
  final firstValue = iter.first;
  for (var value in iter.skip(1)) {
    if (value != firstValue) {
      return false;
    }
  }
  return true;
}

/// Returns whether [span] covers multiple lines.
bool isMultiline(SourceSpan span) => span.start.line != span.end.line;

/// Sets the first `null` element of [list] to [element].
void replaceFirstNull<E>(List<E?> list, E element) {
  final index = list.indexOf(null);
  if (index < 0) throw ArgumentError('$list contains no null elements.');
  list[index] = element;
}

/// Sets the element of [list] that currently contains [element] to `null`.
void replaceWithNull<E>(List<E?> list, E element) {
  final index = list.indexOf(element);
  if (index < 0) {
    throw ArgumentError('$list contains no elements matching $element.');
  }

  list[index] = null;
}

/// Returns the number of instances of [codeUnit] in [string].
int countCodeUnits(String string, int codeUnit) {
  var count = 0;
  for (var codeUnitToCheck in string.codeUnits) {
    if (codeUnitToCheck == codeUnit) count++;
  }
  return count;
}

/// Returns whether [text] has a line terminator at [index].
///
/// A line terminator is either `\n` or a `\r` not immediately followed by `\n`.
bool _isLineEnd(String text, int index) {
  final codeUnit = text.codeUnitAt(index);
  if (codeUnit == $lf) return true;
  if (codeUnit != $cr) return false;
  return index + 1 == text.length || text.codeUnitAt(index + 1) != $lf;
}

/// Returns the index of the next line terminator in [text] at or after [start],
/// or `-1` if none exists.
int _indexOfLineEnd(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (_isLineEnd(text, i)) return i;
  }
  return -1;
}

/// Returns the start index of the line containing [index] in [text].
int _lineStartAt(String text, int index) {
  for (var i = index - 1; i >= 0; i--) {
    if (_isLineEnd(text, i)) return i + 1;
  }
  return 0;
}

/// Finds a line in [context] containing [text] at the specified [column].
///
/// Returns the index in [context] where that line begins, or null if none
/// exists.
int? findLineStart(String context, String text, int column) {
  // If the text is empty, we just want to find the first line that has at least
  // [column] characters.
  if (text.isEmpty) {
    var beginningOfLine = 0;
    while (true) {
      final index = _indexOfLineEnd(context, beginningOfLine);
      if (index == -1) {
        return context.length - beginningOfLine >= column
            ? beginningOfLine
            : null;
      }
      if (index - beginningOfLine >= column) return beginningOfLine;
      beginningOfLine = index + 1;
    }
  }

  var index = context.indexOf(text);
  while (index != -1) {
    // Start looking before [index] in case [text] starts with a newline.
    final lineStart = _lineStartAt(context, index);
    final textColumn = index - lineStart;
    if (column == textColumn) return lineStart;
    index = context.indexOf(text, index + 1);
  }
  // ignore: avoid_returning_null
  return null;
}

/// Finds the line in `span.context` containing [span], returning both the
/// code-unit offset where that line begins and the number of preceding context
/// lines.
///
/// Uses [span]'s start and end location metadata to disambiguate when multiple
/// lines in `span.context` contain `span.text` at `span.start.column`. Returns
/// `null` if no line matches.
({int lineStart, int linesBefore})? findSpanLineStart(
    SourceSpanWithContext span) {
  if (span is FileSpan) return (lineStart: 0, linesBefore: 0);

  final context = span.context;
  ({int lineStart, int linesBefore})? best;
  var bestTier = 0;

  var lineStart = 0;
  var linesBefore = 0;
  while (true) {
    final lineEnd = _indexOfLineEnd(context, lineStart);
    var effectiveLineEnd = lineEnd == -1 ? context.length : lineEnd;
    if (lineEnd != -1 &&
        lineEnd > lineStart &&
        context.codeUnitAt(lineEnd - 1) == $cr) {
      effectiveLineEnd--;
    }

    final tier =
        _scoreSpanLineCandidate(span, lineStart, effectiveLineEnd, linesBefore);
    if (tier > bestTier) {
      best = (lineStart: lineStart, linesBefore: linesBefore);
      bestTier = tier;
    }
    if (lineEnd == -1) return best;
    lineStart = lineEnd + 1;
    linesBefore++;
  }
}

/// Scores a candidate line at [lineStart] (after [linesBefore] lines) in
/// `span.context`, returning `0` when [span] cannot start on this line or
/// `1..4` (higher is better) when it matches.
int _scoreSpanLineCandidate(
  SourceSpanWithContext span,
  int lineStart,
  int effectiveLineEnd,
  int linesBefore,
) {
  final context = span.context;
  final text = span.text;
  final column = span.start.column;
  if (column > effectiveLineEnd - lineStart) return 0;

  final textStart = lineStart + column;
  if (textStart + text.length > context.length ||
      !context.startsWith(text, textStart)) {
    return 0;
  }
  if (!_matchesEndLocation(context, textStart, span)) return 1;
  return 2;
}

/// Returns whether advancing `span.text.length` code units from [textStart] in
/// [context] lands on `span.end.line` and `span.end.column`.
bool _matchesEndLocation(String context, int textStart, SourceSpan span) {
  var line = span.start.line;
  var column = span.start.column;
  final textEnd = textStart + span.text.length;
  for (var i = textStart; i < textEnd; i++) {
    if (_isLineEnd(context, i)) {
      line++;
      column = 0;
    } else {
      column++;
    }
  }
  return line == span.end.line && column == span.end.column;
}

/// Returns a two-element list containing the start and end locations of the
/// span from [start] code units (inclusive) to [end] code units (exclusive)
/// after the beginning of [span].
///
/// This is factored out so it can be shared between
/// [SourceSpanExtension.subspan] and [SourceSpanWithContextExtension.subspan].
List<SourceLocation> subspanLocations(SourceSpan span, int start, [int? end]) {
  if (start == span.length) return [span.end, span.end];

  final text = span.text;
  final startLocation = span.start;
  var line = startLocation.line;
  var column = startLocation.column;

  // Adjust [line] and [column] as necessary if the character at [i] in [text]
  // is a newline.
  void consumeCodePoint(int i) {
    final codeUnit = text.codeUnitAt(i);
    if (codeUnit == $lf ||
        // A carriage return counts as a newline, but only if it's not
        // followed by a line feed.
        (codeUnit == $cr && text.codeUnitAt(i + 1) != $lf)) {
      line += 1;
      column = 0;
    } else {
      column += 1;
    }
  }

  for (var i = 0; i < start; i++) {
    consumeCodePoint(i);
  }

  final newStartLocation = SourceLocation(startLocation.offset + start,
      sourceUrl: span.sourceUrl, line: line, column: column);

  SourceLocation newEndLocation;
  if (end == null || end == span.length) {
    newEndLocation = span.end;
  } else if (end == start) {
    newEndLocation = newStartLocation;
  } else {
    for (var i = start; i < end; i++) {
      consumeCodePoint(i);
    }
    newEndLocation = SourceLocation(startLocation.offset + end,
        sourceUrl: span.sourceUrl, line: line, column: column);
  }

  return [newStartLocation, newEndLocation];
}
