// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'block_parser.dart';
import 'block_syntaxes/block_syntax.dart';
import 'charcode.dart';
import 'util.dart';

class LinkParser {
  final BlockParser _blockParser;

  /// The source text accumulated from consumed lines so far.
  String _source;

  /// The current read position in [_source].
  int _pos = 0;

  /// How many lines have been consumed from [_blockParser].
  int _linesConsumed = 1;

  /// If there is a valid link formed.
  bool get valid => _valid;
  bool _valid = false;

  /// Link label.
  String? get label => _label;
  String? _label;

  /// Link destination.
  String? get destination => _destination;
  String? _destination;

  /// Link title.
  String? get title => _title;
  String? _title;

  LinkParser(this._blockParser) : _source = _blockParser.current.content {
    _blockParser.advance();
  }

  int get pos => _pos;

  int get length => _source.length;

  bool get isDone => _pos == _source.length;

  int charAt([int? position]) => _source.codeUnitAt(position ?? _pos);

  void advance() {
    _pos++;
  }

  String substring(int start, [int? end]) => _source.substring(start, end);

  /// Walks the parser forward through horizontal whitespace on the current
  /// line.
  int moveThroughWhitespace() {
    var i = 0;
    while (!isDone) {
      final char = charAt();
      if (char != $space &&
          char != $tab &&
          char != $vt &&
          char != $cr &&
          char != $ff) {
        return i;
      }
      i++;
      advance();
    }
    return i;
  }

  /// Appends the next line from [_blockParser] if not at a block end.
  bool _tryAdvanceLine() {
    if (BlockSyntax.isAtBlockEnd(_blockParser)) {
      return false;
    }
    _source = '$_source\n${_blockParser.current.content}';
    _blockParser.advance();
    _linesConsumed++;
    return true;
  }

  void _retreatTo(int targetLinesConsumed) {
    final delta = _linesConsumed - targetLinesConsumed;
    if (delta > 0) {
      _blockParser.retreatBy(delta);
      _linesConsumed = targetLinesConsumed;
    }
  }

  /// Whether [line] begins with optional horizontal whitespace followed by a
  /// link title opening delimiter (`'`, `"`, or `(`).
  static bool _startsWithTitleDelimiter(String line) {
    for (var i = 0; i < line.length; i++) {
      final char = line.codeUnitAt(i);
      if (char == $space ||
          char == $tab ||
          char == $vt ||
          char == $cr ||
          char == $ff) {
        continue;
      }
      return char == $apostrophe || char == $quote || char == $lparen;
    }
    return false;
  }

  /// Parses [_source] to a link reference definition.
  void parseDefinition() {
    if (!parseLabel() || isDone || charAt() != $colon) {
      _retreatTo(0);
      return;
    }

    // Advance to the next character after the colon.
    advance();
    if (!_parseDestination()) {
      _retreatTo(0);
      return;
    }

    final precedingWhitespaces = moveThroughWhitespace();
    if (!isDone) {
      // A title on the same line as the destination must be preceded by
      // whitespace, and nothing but whitespace may follow the closing delimiter
      // on its line.
      // For example: `[foo]: <bar> "baz` is an invalid definition, and
      // `[foo]: <bar> "baz" hello` is also invalid
      // (see https://spec.commonmark.org/0.30/#example-209).
      if (precedingWhitespaces == 0 || !_parseTitle()) {
        _retreatTo(0);
        return;
      }
      moveThroughWhitespace();
      if (!isDone) {
        _title = null;
        _retreatTo(0);
        return;
      }
      _valid = true;
      return;
    }

    // We reached the end of the destination's line, so `[label]: destination`
    // is already valid even if the next line is not a valid title
    // (see https://spec.commonmark.org/0.30/#example-210).
    final savedLinesConsumed = _linesConsumed;
    if (!_blockParser.isDone &&
        _startsWithTitleDelimiter(_blockParser.current.content) &&
        _tryAdvanceLine()) {
      // Advance past the line feed.
      advance();
      moveThroughWhitespace();
      if (_parseTitle()) {
        moveThroughWhitespace();
        if (!isDone) {
          _title = null;
          _retreatTo(savedLinesConsumed);
        }
      } else {
        _title = null;
        _retreatTo(savedLinesConsumed);
      }
    }

    _valid = true;
  }

  /// Parses the link label, returns `true` if there is a valid link label.
  bool parseLabel() {
    moveThroughWhitespace();

    if (isDone || charAt() != $lbracket) {
      return false;
    }

    // Advance past the opening `[`.
    advance();
    final start = pos;

    // A link label can have at most 999 characters inside the square brackets.
    // See https://spec.commonmark.org/0.30/#link-label.
    var maxLoop = 999;
    while (true) {
      if (maxLoop-- < 0) {
        return false;
      }
      if (isDone && !_tryAdvanceLine()) {
        return false;
      }
      final char = charAt();
      if (char == $backslash) {
        advance();
        if (isDone && !_tryAdvanceLine()) {
          return false;
        }
      } else if (char == $lbracket) {
        return false;
      } else if (char == $rbracket) {
        break;
      }
      advance();
    }

    final text = substring(start, pos);
    if (text.isBlank) {
      return false;
    }

    // Advance past the closing `]`.
    advance();
    _label = text;
    return true;
  }

  /// Parses the link destination, returns `true` if there is a valid link
  /// destination.
  bool _parseDestination() {
    moveThroughWhitespace();
    if (isDone) {
      if (!_tryAdvanceLine()) {
        return false;
      }
      // Advance past the line feed.
      advance();
      moveThroughWhitespace();
      if (isDone) {
        return false;
      }
    }

    final isValidDestination = charAt() == $lt
        ? _parseBracketedDestination()
        : _parseBareDestination();

    return isValidDestination;
  }

  /// Parses bracketed destinations (destinations wrapped in `<...>`). The
  /// current position of the parser must be the first character of the
  /// destination.
  ///
  /// Returns `true` if there is a valid link destination.
  bool _parseBracketedDestination() {
    // Walk past the opening `<`.
    advance();
    if (isDone) {
      return false;
    }

    final start = pos;
    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
        if (isDone) {
          return false;
        }
      } else if (char == $lf || char == $cr || char == $ff) {
        return false;
      } else if (char == $gt) {
        break;
      }
      advance();
      if (isDone) {
        return false;
      }
    }

    _destination = substring(start, pos);

    // Advance past the closing `>`.
    advance();
    return true;
  }

  /// Parse "bare" destinations (destinations _not_ wrapped in `<...>`). The
  /// current position of the parser must be the first character of the
  /// destination.
  ///
  /// Returns `true` if there is a valid link destination.
  bool _parseBareDestination() {
    var parenCount = 0;
    final start = pos;

    while (true) {
      final char = charAt();
      if (char == $backslash) {
        advance();
        if (isDone) {
          break;
        }
      } else if (char == $space || char == $lf || char == $cr || char == $ff) {
        break;
      } else if (char == $lparen) {
        parenCount++;
      } else if (char == $rparen) {
        parenCount--;
        if (parenCount < 0) {
          return false;
        }
      }
      advance();

      // There is no ending delimiter, so `isDone` also means it is at the end
      // of a link destination.
      if (isDone) {
        break;
      }
    }

    if (parenCount != 0) {
      return false;
    }

    _destination = substring(start, pos);
    return true;
  }

  /// Parses the **optional** link title, returns `true` if there is a valid
  /// link title.
  bool _parseTitle() {
    // See: https://spec.commonmark.org/0.30/#link-title
    // The whitespace should be followed by a title delimiter.
    final delimiter = charAt();
    if (delimiter != $apostrophe &&
        delimiter != $quote &&
        delimiter != $lparen) {
      return false;
    }

    final closeDelimiter = delimiter == $lparen ? $rparen : delimiter;
    advance();
    final start = pos;

    // Looking for an un-escaped closing delimiter.
    while (true) {
      if (isDone && !_tryAdvanceLine()) {
        return false;
      }
      final char = charAt();
      if (char == $backslash) {
        advance();
        if (isDone && !_tryAdvanceLine()) {
          return false;
        }
      } else if (char == closeDelimiter) {
        break;
      } else if (delimiter == $lparen && char == $lparen) {
        return false;
      }
      advance();
    }

    _title = substring(start, pos);

    // Advance past the closing delimiter.
    advance();
    return true;
  }
}
