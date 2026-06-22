// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'charcode.dart';
import 'string_scanner.dart';
import 'utils.dart';

// Note that much of this code is duplicated in eager_span_scanner.dart.

/// A subclass of [StringScanner] that tracks line and column information.
class LineScanner extends StringScanner {
  /// The scanner's current (zero-based) line number.
  int get line => _line;
  int _line = 0;

  /// The scanner's current (zero-based) column number.
  int get column => _column;
  int _column = 0;

  /// The scanner's state, including line and column information.
  ///
  /// This can be used to efficiently save and restore the state of the scanner
  /// when backtracking. A given [LineScannerState] is only valid for the
  /// [LineScanner] that created it.
  ///
  /// This does not include the scanner's match information.
  LineScannerState get state =>
      LineScannerState._(this, position, line, column);

  set state(LineScannerState state) {
    if (!identical(state._scanner, this)) {
      throw ArgumentError('The given LineScannerState was not returned by '
          'this LineScanner.');
    }

    super.position = state.position;
    _line = state.line;
    _column = state.column;
  }

  @override
  set position(int newPosition) {
    if (newPosition == position) {
      return;
    }

    final oldPosition = position;
    super.position = newPosition;

    if (newPosition == 0) {
      _line = 0;
      _column = 0;
    } else if (newPosition > oldPosition) {
      var newlines = 0;
      var lastNewlineEnd = -1;
      for (var i = oldPosition; i < newPosition; i++) {
        final char = string.codeUnitAt(i);
        if (char == $lf) {
          newlines++;
          lastNewlineEnd = i + 1;
        } else if (char == $cr) {
          final nextIsLf =
              (i + 1 < newPosition && string.codeUnitAt(i + 1) == $lf) ||
                  (i + 1 == newPosition &&
                      newPosition < string.length &&
                      string.codeUnitAt(newPosition) == $lf);
          if (!nextIsLf) {
            newlines++;
            lastNewlineEnd = i + 1;
          }
        }
      }
      _line += newlines;
      if (newlines == 0) {
        _column += newPosition - oldPosition;
      } else {
        _column = newPosition - lastNewlineEnd;
      }
    } else {
      var newlines = 0;
      for (var i = newPosition; i < oldPosition; i++) {
        final char = string.codeUnitAt(i);
        if (char == $lf) {
          newlines++;
        } else if (char == $cr) {
          if (i + 1 < oldPosition) {
            if (string.codeUnitAt(i + 1) != $lf) newlines++;
          } else {
            // i + 1 == oldPosition
            if (oldPosition >= string.length ||
                string.codeUnitAt(oldPosition) != $lf) {
              newlines++;
            }
          }
        }
      }
      _line -= newlines;

      if (newlines == 0) {
        _column -= oldPosition - newPosition;
      } else {
        var offsetAfterLastNewline = 0;
        for (var i = newPosition - 1; i >= 0; i--) {
          final char = string.codeUnitAt(i);
          if (char == $lf) {
            offsetAfterLastNewline = i + 1;
            break;
          } else if (char == $cr) {
            if (i + 1 < string.length && string.codeUnitAt(i + 1) == $lf) {
              continue;
            }
            offsetAfterLastNewline = i + 1;
            break;
          }
        }
        _column = newPosition - offsetAfterLastNewline;
      }
    }
  }

  LineScanner(super.string, {super.sourceUrl, super.position});

  @override
  bool scanChar(int character) {
    if (!super.scanChar(character)) return false;
    _adjustLineAndColumn(character);
    return true;
  }

  @override
  int readChar() {
    final character = super.readChar();
    _adjustLineAndColumn(character);
    return character;
  }

  /// Adjusts [_line] and [_column] after having consumed [character].
  void _adjustLineAndColumn(int character) {
    if (character == $lf) {
      _line += 1;
      _column = 0;
    } else if (character == $cr) {
      if (position < string.length && string.codeUnitAt(position) == $lf) {
        _column += 1;
      } else {
        _line += 1;
        _column = 0;
      }
    } else {
      _column += inSupplementaryPlane(character) ? 2 : 1;
    }
  }

  @override
  bool scan(Pattern pattern) {
    if (!super.scan(pattern)) return false;

    final match = lastMatch![0]!;
    var newlines = 0;
    var lastNewlineEnd = -1;
    for (var i = 0; i < match.length; i++) {
      final char = match.codeUnitAt(i);
      if (char == $lf) {
        newlines++;
        lastNewlineEnd = i + 1;
      } else if (char == $cr) {
        if (i + 1 < match.length) {
          if (match.codeUnitAt(i + 1) != $lf) {
            newlines++;
            lastNewlineEnd = i + 1;
          }
        } else {
          // i + 1 == match.length
          if (position >= string.length || string.codeUnitAt(position) != $lf) {
            newlines++;
            lastNewlineEnd = i + 1;
          }
        }
      }
    }

    _line += newlines;
    if (newlines == 0) {
      _column += match.length;
    } else {
      _column = match.length - lastNewlineEnd;
    }

    return true;
  }
}

/// A class representing the state of a [LineScanner].
class LineScannerState {
  /// The [LineScanner] that created this.
  final LineScanner _scanner;

  /// The position of the scanner in this state.
  final int position;

  /// The zero-based line number of the scanner in this state.
  final int line;

  /// The zero-based column number of the scanner in this state.
  final int column;

  LineScannerState._(this._scanner, this.position, this.line, this.column);
}
