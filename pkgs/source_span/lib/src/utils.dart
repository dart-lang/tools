// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'span.dart';

/// Returns the minimum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
T min<T extends Comparable>(T obj1, T obj2) =>
    obj1.compareTo(obj2) > 0 ? obj2 : obj1;

/// Returns the maximum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
T max<T extends Comparable>(T obj1, T obj2) =>
    obj1.compareTo(obj2) > 0 ? obj1 : obj2;

/// Returns whether all elements of [iter] are the same value, according to
/// `==`.
bool isAllTheSame(Iterable<Object> iter) {
  Object? lastValue;
  for (var value in iter) {
    if (lastValue == null) {
      lastValue = value;
    } else if (value != lastValue) {
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
      final index = context.indexOf('\n', beginningOfLine);
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
    final lineStart = index == 0 ? 0 : context.lastIndexOf('\n', index - 1) + 1;
    final textColumn = index - lineStart;
    if (column == textColumn) return lineStart;
    index = context.indexOf(text, index + 1);
  }
  // ignore: avoid_returning_null
  return null;
}
