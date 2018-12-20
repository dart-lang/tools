// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Returns the minimum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
Comparable min(Comparable obj1, Comparable obj2) =>
    obj1.compareTo(obj2) > 0 ? obj2 : obj1;

/// Returns the maximum of [obj1] and [obj2] according to
/// [Comparable.compareTo].
Comparable max(Comparable obj1, Comparable obj2) =>
    obj1.compareTo(obj2) > 0 ? obj1 : obj2;

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
int findLineStart(String context, String text, int column) {
  // If the text is empty, we just want to find the first line that has at least
  // [column] characters.
  if (text.isEmpty) {
    var beginningOfLine = 0;
    while (true) {
      var index = context.indexOf("\n", beginningOfLine);
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
    var lineStart = index == 0 ? 0 : context.lastIndexOf('\n', index - 1) + 1;
    var textColumn = index - lineStart;
    if (column == textColumn) return lineStart;
    index = context.indexOf(text, index + 1);
  }
  return null;
}
