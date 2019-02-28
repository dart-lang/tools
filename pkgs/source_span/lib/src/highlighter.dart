// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import 'colors.dart' as colors;
import 'location.dart';
import 'span.dart';
import 'span_with_context.dart';
import 'utils.dart';

/// A class for writing a chunk of text with a particular span highlighted.
class Highlighter {
  /// The span to highlight.
  final SourceSpanWithContext _span;

  /// The color to highlight [_span] within its context, or `null` if the span
  /// should not be colored.
  final String _color;

  /// Whether [_span] covers multiple lines.
  final bool _multiline;

  /// The number of characters before the bar in the sidebar.
  final int _paddingBeforeSidebar;

  // The number of characters between the bar in the sidebar and the text
  // being highlighted.
  int get _paddingAfterSidebar =>
      // This is just a space for a single-line span, but for a multi-line span
      // needs to accommodate " | ".
      _multiline ? 3 : 1;

  /// The buffer to which to write the result.
  final _buffer = new StringBuffer();

  /// The number of spaces to render for hard tabs that appear in `_span.text`.
  ///
  /// We don't want to render raw tabs, because they'll mess up our character
  /// alignment.
  static const _spacesPerTab = 4;

  /// Creats a [Highlighter] that will return a message associated with [span]
  /// when [write] is called.
  ///
  /// [color] may either be a [String], a [bool], or `null`. If it's a string,
  /// it indicates an [ANSI terminal color
  /// escape](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors) that should
  /// be used to highlight the span's text (for example, `"\u001b[31m"` will
  /// color red). If it's `true`, it indicates that the text should be
  /// highlighted using the default color. If it's `false` or `null`, it
  /// indicates that the text shouldn't be highlighted.
  factory Highlighter(SourceSpan span, {color}) {
    if (color == true) color = colors.RED;
    if (color == false) color = null;

    var newSpan = _normalizeContext(span);
    newSpan = _normalizeNewlines(newSpan);
    newSpan = _normalizeTrailingNewline(newSpan);
    newSpan = _normalizeEndOfLine(newSpan);

    return new Highlighter._(newSpan, color);
  }

  /// Normalizes [span] to ensure that it's a [SourceSpanWithContext] whose
  /// context actually contains its text at the expected column.
  ///
  /// If it's not already a [SourceSpanWithContext], adjust the start and end
  /// locations' line and column fields so that the highlighter can assume they
  /// match up with the context.
  static SourceSpanWithContext _normalizeContext(SourceSpan span) =>
      span is SourceSpanWithContext &&
              findLineStart(span.context, span.text, span.start.column) != null
          ? span
          : new SourceSpanWithContext(
              new SourceLocation(span.start.offset,
                  sourceUrl: span.sourceUrl, line: 0, column: 0),
              new SourceLocation(span.end.offset,
                  sourceUrl: span.sourceUrl,
                  line: countCodeUnits(span.text, $lf),
                  column: _lastLineLength(span.text)),
              span.text,
              span.text);

  /// Normalizes [span] to replace Windows-style newlines with Unix-style
  /// newlines.
  static SourceSpanWithContext _normalizeNewlines(SourceSpanWithContext span) {
    var text = span.text;
    if (!text.contains("\r\n")) return span;

    var endOffset = span.end.offset;
    for (var i = 0; i < text.length - 1; i++) {
      if (text.codeUnitAt(i) == $cr && text.codeUnitAt(i + 1) == $lf) {
        endOffset--;
      }
    }

    return new SourceSpanWithContext(
        span.start,
        new SourceLocation(endOffset,
            sourceUrl: span.sourceUrl,
            line: span.end.line,
            column: span.end.column),
        text.replaceAll("\r\n", "\n"),
        span.context.replaceAll("\r\n", "\n"));
  }

  /// Normalizes [span] to remove a trailing newline from `span.context`.
  ///
  /// If necessary, also adjust `span.end` so that it doesn't point past where
  /// the trailing newline used to be.
  static SourceSpanWithContext _normalizeTrailingNewline(
      SourceSpanWithContext span) {
    if (!span.context.endsWith("\n")) return span;

    // If there's a full blank line on the end of [span.context], it's probably
    // significant, so we shouldn't trim it.
    if (span.text.endsWith("\n\n")) return span;

    var context = span.context.substring(0, span.context.length - 1);
    var text = span.text;
    var start = span.start;
    var end = span.end;
    if (span.text.endsWith("\n") && _isTextAtEndOfContext(span)) {
      text = span.text.substring(0, span.text.length - 1);
      end = new SourceLocation(span.end.offset - 1,
          sourceUrl: span.sourceUrl,
          line: span.end.line - 1,
          column: _lastLineLength(text));
      start = span.start.offset == span.end.offset ? end : span.start;
    }
    return new SourceSpanWithContext(start, end, text, context);
  }

  /// Normalizes [span] so that the end location is at the end of a line rather
  /// than at the beginning of the next line.
  static SourceSpanWithContext _normalizeEndOfLine(SourceSpanWithContext span) {
    if (span.end.column != 0) return span;
    if (span.end.line == span.start.line) return span;

    var text = span.text.substring(0, span.text.length - 1);

    return new SourceSpanWithContext(
        span.start,
        new SourceLocation(span.end.offset - 1,
            sourceUrl: span.sourceUrl,
            line: span.end.line - 1,
            column: _lastLineLength(text)),
        text,
        span.context);
  }

  /// Returns the length of the last line in [text], whether or not it ends in a
  /// newline.
  static int _lastLineLength(String text) {
    if (text.isEmpty) return 0;

    // The "- 1" here avoids counting the newline itself.
    if (text.codeUnitAt(text.length - 1) == $lf) {
      return text.length == 1
          ? 0
          : text.length - text.lastIndexOf("\n", text.length - 2) - 1;
    } else {
      return text.length - text.lastIndexOf("\n") - 1;
    }
  }

  /// Returns whether [span]'s text runs all the way to the end of its context.
  static bool _isTextAtEndOfContext(SourceSpanWithContext span) =>
      findLineStart(span.context, span.text, span.start.column) +
          span.start.column +
          span.length ==
      span.context.length;

  Highlighter._(this._span, this._color)
      : _multiline = _span.start.line != _span.end.line,
        // In a purely mathematical world, floor(log10(n)) would give the number of
        // digits in n, but floating point errors render that unreliable in
        // practice.
        _paddingBeforeSidebar = _span.end.line.toString().length + 1;

  /// Returns the highlighted span text.
  ///
  /// This method should only be called once.
  String highlight() {
    _writeSidebar(end: glyph.downEnd);
    _buffer.writeln();

    // If [_span.context] contains lines prior to the one [_span.text] appears
    // on, write those first.
    var lineStart =
        findLineStart(_span.context, _span.text, _span.start.column);
    assert(lineStart != null); // enforced by [_normalizeContext]

    var context = _span.context;
    if (lineStart > 0) {
      // Take a substring to one character *before* [lineStart] because
      // [findLineStart] is guaranteed to return a position immediately after a
      // newline. Including that newline would add an extra empty line to the
      // end of [lines].
      var lines = context.substring(0, lineStart - 1).split("\n");
      var lineNumber = _span.start.line - lines.length;
      for (var line in lines) {
        _writeSidebar(line: lineNumber);
        _buffer.write(" " * _paddingAfterSidebar);
        _writeText(line);
        _buffer.writeln();
        lineNumber++;
      }
      context = context.substring(lineStart);
    }

    var lines = context.split("\n");

    var lastLineIndex = _span.end.line - _span.start.line;
    if (lines.last.isEmpty && lines.length > lastLineIndex + 1) {
      // Trim a trailing newline so we don't add an empty line to the end of the
      // highlight.
      lines.removeLast();
    }

    _writeFirstLine(lines.first);
    if (_multiline) {
      _writeIntermediateLines(lines.skip(1).take(lastLineIndex - 1));
      _writeLastLine(lines[lastLineIndex]);
    }
    _writeTrailingLines(lines.skip(lastLineIndex + 1));

    _writeSidebar(end: glyph.upEnd);

    return _buffer.toString();
  }

  // Writes the first (and possibly only) line highlighted by the span.
  void _writeFirstLine(String line) {
    _writeSidebar(line: _span.start.line);

    var startColumn = math.min(_span.start.column, line.length);
    var endColumn = math.min(
        startColumn + _span.end.offset - _span.start.offset, line.length);
    var textBefore = line.substring(0, startColumn);

    // If the span covers the entire first line other than initial whitespace,
    // don't bother pointing out exactly where it begins.
    if (_multiline && _isOnlyWhitespace(textBefore)) {
      _buffer.write(" ");
      _colorize(() {
        _buffer.write(glyph.glyphOrAscii("┌", "/"));
        _buffer.write(" ");
        _writeText(line);
      });
      _buffer.writeln();
      return;
    }

    _buffer.write(" " * _paddingAfterSidebar);
    _writeText(textBefore);
    var textInside = line.substring(startColumn, endColumn);
    _colorize(() => _writeText(textInside));
    _writeText(line.substring(endColumn));
    _buffer.writeln();

    // Adjust the start and end column to account for any tabs that were
    // converted to spaces.
    var tabsBefore = _countTabs(textBefore);
    var tabsInside = _countTabs(textInside);
    startColumn = startColumn + tabsBefore * (_spacesPerTab - 1);
    endColumn = endColumn + (tabsBefore + tabsInside) * (_spacesPerTab - 1);

    // Write the highlight for the first line. This is a series of carets for a
    // single-line span, and a pointer to the beginning of a multi-line span.
    _writeSidebar();
    if (_multiline) {
      _buffer.write(" ");
      _colorize(() {
        _buffer.write(glyph.topLeftCorner);
        _buffer.write(glyph.horizontalLine * (startColumn + 1));
        _buffer.write("^");
      });
    } else {
      _buffer.write(" " * (startColumn + 1));
      _colorize(
          () => _buffer.write("^" * math.max(endColumn - startColumn, 1)));
    }
    _buffer.writeln();
  }

  /// Writes the lines between the first and last lines highlighted by the span.
  void _writeIntermediateLines(Iterable<String> lines) {
    assert(_multiline);

    // +1 because the first line was already written.
    var lineNumber = _span.start.line + 1;
    for (var line in lines) {
      _writeSidebar(line: lineNumber);

      _buffer.write(" ");
      _colorize(() {
        _buffer.write(glyph.verticalLine);
        _buffer.write(" ");
        _writeText(line);
      });
      _buffer.writeln();

      lineNumber++;
    }
  }

  // Writes the last line highlighted by the span.
  void _writeLastLine(String line) {
    assert(_multiline);

    _writeSidebar(line: _span.end.line);

    var endColumn = math.min(_span.end.column, line.length);

    // If the span covers the entire last line, don't bother pointing out
    // exactly where it ends.
    if (_multiline && endColumn == line.length) {
      _buffer.write(" ");
      _colorize(() {
        _buffer.write(glyph.glyphOrAscii("└", "\\"));
        _buffer.write(" ");
        _writeText(line);
      });
      _buffer.writeln();
      return;
    }

    _buffer.write(" ");
    var textInside = line.substring(0, endColumn);
    _colorize(() {
      _buffer.write(glyph.verticalLine);
      _buffer.write(" ");
      _writeText(textInside);
    });
    _writeText(line.substring(endColumn));
    _buffer.writeln();

    // Adjust the end column to account for any tabs that were converted to
    // spaces.
    var tabsInside = _countTabs(textInside);
    endColumn = endColumn + tabsInside * (_spacesPerTab - 1);

    // Write the highlight for the final line, which is an arrow pointing to the
    // end of the span.
    _writeSidebar();
    _buffer.write(" ");
    _colorize(() {
      _buffer.write(glyph.bottomLeftCorner);
      _buffer.write(glyph.horizontalLine * endColumn);
      _buffer.write("^");
    });
    _buffer.writeln();
  }

  /// Writes lines that appear in the context string but come after the span.
  void _writeTrailingLines(Iterable<String> lines) {
    // +1 because this comes after any lines covered by the span.
    var lineNumber = _span.end.line + 1;
    for (var line in lines) {
      _writeSidebar(line: lineNumber);
      _buffer.write(" " * _paddingAfterSidebar);
      _writeText(line);
      _buffer.writeln();
      lineNumber++;
    }
  }

  /// Writes a snippet from the source text, converting hard tab characters into
  /// plain indentation.
  void _writeText(String text) {
    for (var char in text.codeUnits) {
      if (char == $tab) {
        _buffer.write(" " * _spacesPerTab);
      } else {
        _buffer.writeCharCode(char);
      }
    }
  }

  // Writes a sidebar to [buffer] that includes [line] as the line number if
  // given and writes [end] at the end (defaults to [glyphs.verticalLine]).
  void _writeSidebar({int line, String end}) {
    _colorize(() {
      if (line != null) {
        // Add 1 to line to convert from computer-friendly 0-indexed line
        // numbers to human-friendly 1-indexed line numbers.
        _buffer.write((line + 1).toString().padRight(_paddingBeforeSidebar));
      } else {
        _buffer.write(" " * _paddingBeforeSidebar);
      }
      _buffer.write(end ?? glyph.verticalLine);
    }, color: colors.BLUE);
  }

  /// Returns the number of hard tabs in [text].
  int _countTabs(String text) {
    var count = 0;
    for (var char in text.codeUnits) {
      if (char == $tab) count++;
    }
    return count;
  }

  /// Returns whether [text] contains only space or tab characters.
  bool _isOnlyWhitespace(String text) {
    for (var char in text.codeUnits) {
      if (char != $space && char != $tab) return false;
    }
    return true;
  }

  /// Colors all text written to [_buffer] during [callback], if colorization is
  /// enabled.
  ///
  /// If [color] is passed, it's used as the color; otherwise, [_color] is used.
  void _colorize(void callback(), {String color}) {
    if (_color != null) _buffer.write(color ?? _color);
    callback();
    if (_color != null) _buffer.write(colors.NONE);
  }
}
