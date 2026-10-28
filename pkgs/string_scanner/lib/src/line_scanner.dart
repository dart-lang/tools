// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'charcode.dart';
import 'span_scanner.dart';
import 'string_scanner.dart';
import 'utils.dart';

mixin _LineScanner on StringScanner {
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
    final oldPosition = position;
    super.position = newPosition;
    if (newPosition == oldPosition) {
      return;
    }

    if (newPosition == 0) {
      _line = 0;
      _column = 0;
    } else if (newPosition > oldPosition) {
      _advancePosition(oldPosition, newPosition);
    } else {
      var newlines = 0;
      for (var i = newPosition; i < oldPosition; i++) {
        if (_isNewlineAt(i)) newlines++;
      }
      _line -= newlines;

      if (newlines == 0) {
        _column -= oldPosition - newPosition;
      } else {
        var offsetAfterLastNewline = 0;
        for (var i = newPosition - 1; i >= 0; i--) {
          if (_isNewlineAt(i)) {
            offsetAfterLastNewline = i + 1;
            break;
          }
        }
        _column = newPosition - offsetAfterLastNewline;
      }
    }
  }

  /// Returns whether the character at [index] in [string] is a line break
  /// (`\n`, or `\r` not immediately followed by `\n`).
  bool _isNewlineAt(int index) {
    final char = string.codeUnitAt(index);
    return char == $lf ||
        (char == $cr &&
            (index + 1 == string.length ||
                string.codeUnitAt(index + 1) != $lf));
  }

  void _advancePosition(int oldPosition, int newPosition) {
    var newlines = 0;
    var lastNewlineEnd = -1;
    for (var i = oldPosition; i < newPosition; i++) {
      if (_isNewlineAt(i)) {
        newlines++;
        lastNewlineEnd = i + 1;
      }
    }
    _line += newlines;
    if (newlines == 0) {
      _column += newPosition - oldPosition;
    } else {
      _column = newPosition - lastNewlineEnd;
    }
  }

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
    final oldPosition = position;
    if (!super.scan(pattern)) return false;
    _advancePosition(oldPosition, position);
    return true;
  }
}

/// A [StringScanner] that tracks line and column information.
class LineScanner extends StringScanner with _LineScanner {
  LineScanner(super.string, {super.sourceUrl, super.position});
}

/// A [SpanScanner] that tracks the line and column eagerly, like [LineScanner].
@internal
class EagerSpanScanner extends SpanScanner with _LineScanner {
  EagerSpanScanner(super.string, {super.sourceUrl, super.position});
}

/// A class representing the state of a [LineScanner].
class LineScannerState {
  /// The [StringScanner] that created this.
  final StringScanner _scanner;

  /// The position of the scanner in this state.
  final int position;

  /// The zero-based line number of the scanner in this state.
  final int line;

  /// The zero-based column number of the scanner in this state.
  final int column;

  LineScannerState._(this._scanner, this.position, this.line, this.column);
}
