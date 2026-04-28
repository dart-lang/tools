// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

/// A simple fake terminal that interprets a subset of ANSI escape sequences
/// to maintain a virtual screen buffer.
///
/// Supported sequences:
/// - `\x1b[nA`: Move cursor up `n` lines.
/// - `\x1b[2K`: Clear the current line.
///
/// Ignored sequences (stripped from output):
/// - `\x1b[1m`: Bold.
/// - `\x1b[0m`: Reset formatting.
/// - `\x1b[?25l`: Hide cursor.
/// - `\x1b[?25h`: Show cursor.
class FakeTerminal {
  final List<String> _lines = [''];
  int _cursorRow = 0;
  int _cursorCol = 0;

  /// Writes text to the terminal, interpreting supported escape sequences.
  void write(String text) {
    // Regex for the specific escape sequences used in select_dialog.dart
    final seqRegex = RegExp(
      r'(\x1b\[\d*A|\x1b\[2K|\x1b\[1m|\x1b\[0m|\x1b\[\?25[lh])',
    );

    var lastEnd = 0;
    for (final match in seqRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        _writeText(text.substring(lastEnd, match.start));
      }

      final seq = match.group(0)!;
      if (seq.endsWith('A')) {
        final n = int.tryParse(seq.substring(2, seq.length - 1)) ?? 1;
        _cursorRow = math.max(0, _cursorRow - n);
      } else if (seq == '\x1b[2K') {
        _lines[_cursorRow] = '';
      } else {
        // Ignore style and cursor visibility sequences
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      _writeText(text.substring(lastEnd));
    }
  }

  void _writeText(String text) {
    final textLines = text.split('\n');
    for (var i = 0; i < textLines.length; i++) {
      if (i > 0) {
        _cursorRow++;
        _cursorCol = 0;
        if (_cursorRow >= _lines.length) {
          _lines.add('');
        }
      }
      final currentLine = _lines[_cursorRow];
      final textToAppend = textLines[i];
      if (_cursorCol < currentLine.length) {
        final end = _cursorCol + textToAppend.length;
        if (end <= currentLine.length) {
          _lines[_cursorRow] =
              currentLine.substring(0, _cursorCol) +
              textToAppend +
              currentLine.substring(end);
        } else {
          _lines[_cursorRow] =
              currentLine.substring(0, _cursorCol) + textToAppend;
        }
      } else {
        _lines[_cursorRow] = currentLine.padRight(_cursorCol) + textToAppend;
      }
      _cursorCol += textToAppend.length;
    }
  }

  /// The currently displayed lines of the terminal.
  List<String> get lines => List.unmodifiable(_lines);

  /// The full displayed content as a single string.
  String get content => _lines.join('\n');

  /// The current cursor row (0-indexed).
  int get cursorRow => _cursorRow;
}
