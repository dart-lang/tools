// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'charcode.dart';
import 'string_scanner.dart';
import 'utils.dart';

// Note that much of this code is duplicated in eager_span_scanner.dart.

/// A regular expression matching newlines. A newline is either a `\n`, a `\r\n`
/// or a `\r` that is not immediately followed by a `\n`.
final _newlineRegExp = RegExp(r'\n|\r\n|\r(?!\n)');

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

  /// Whether the current position is between a CR character and an LF
  /// charactet.
  bool get _betweenCRLF => peekChar(-1) == $cr && peekChar() == $lf;

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
      final newlines = _newlinesIn(string.substring(oldPosition, newPosition),
          endPosition: newPosition);
      _line += newlines.length;
      if (newlines.isEmpty) {
        _column += newPosition - oldPosition;
      } else {
        // The regex got a substring, so we need to account for where it started
        // in the string.
        final offsetOfLastNewline = oldPosition + newlines.last.end;
        _column = newPosition - offsetOfLastNewline;
      }
    } else if (newPosition < oldPosition) {
      final newlines = _newlinesIn(string.substring(newPosition, oldPosition),
          endPosition: oldPosition);

      _line -= newlines.length;
      if (newlines.isEmpty) {
        _column -= oldPosition - newPosition;
      } else {
        // To compute the new column, we need to locate the last newline before
        // the new position. When searching, we must exclude the CR if we're
        // between a CRLF because it's not considered a newline.
        final crOffset = _betweenCRLF ? -1 : 0;
        // Additionally, if we use newPosition as the end of the search and the
        // character at that position itself (the next character) is a newline
        // we should not use it, so also offset to account for that.
        const currentCharOffset = -1;
        final lastNewline = string.lastIndexOf(
            _newlineRegExp, newPosition + currentCharOffset + crOffset);

        // Now we need to know the offset after the newline. This is the index
        // above plus the length of the newline (eg. if we found `\r\n`) we need
        // to add two. However if no newline was found, that index is 0.
        final offsetAfterLastNewline = lastNewline == -1
            ? 0
            : string[lastNewline] == '\r' && string[lastNewline + 1] == '\n'
                ? lastNewline + 2
                : lastNewline + 1;

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
    if (character == $lf || (character == $cr && peekChar() != $lf)) {
      _line += 1;
      _column = 0;
    } else {
      _column += inSupplementaryPlane(character) ? 2 : 1;
    }
  }

  @override
  bool scan(Pattern pattern) {
    if (!super.scan(pattern)) return false;

    final newlines = _newlinesIn(lastMatch![0]!, endPosition: position);
    _line += newlines.length;
    if (newlines.isEmpty) {
      _column += lastMatch![0]!.length;
    } else {
      _column = lastMatch![0]!.length - newlines.last.end;
    }

    return true;
  }

  /// Returns a list of [Match]es describing all the newlines in [text], which
  /// ends at [endPosition].
  ///
  /// If [text] ends with `\r`, it will only be treated as a newline if the next
  /// character at [position] is not a `\n`.
  List<Match> _newlinesIn(String text, {required int endPosition}) {
    final newlines = _newlineRegExp.allMatches(text).toList();
    // If the last character is a `\r` it will have been treated as a newline,
    // but this is only valid if the next character is not a `\n`.
    if (endPosition < string.length &&
        text.endsWith('\r') &&
        string[endPosition] == '\n') {
      // newlines should never be empty here, because if `text` ends with `\r`
      // it would have matched `\r(?!\n)` in the newline regex.
      newlines.removeLast();
    }
    return newlines;
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
