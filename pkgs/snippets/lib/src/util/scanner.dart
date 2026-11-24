// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

final _restOfLine = RegExp(r'[^\r\n]*');
final _lineEnding = RegExp(r'\r\n|\r|\n');
final _whitespace = RegExp(r'[ \t]+');
final _nonWhitespace = RegExp(r'[^ \t]+');

extension StringScannerScanExtension on StringScanner {
  /// Scans [pattern] if it matches at [position], returning the matched text or
  /// `''`.
  String scanText(Pattern pattern) => scan(pattern) ? lastMatch![0]! : '';

  /// Advances past the remainder of the current line and its line ending.
  void skipLine() {
    scan(_restOfLine);
    scan(_lineEnding);
  }
}

extension SpanScannerScanExtension on SpanScanner {
  /// Scans to the end of the current line, consumes its line ending if any,
  /// and returns the span of the line without the line ending.
  FileSpan scanLine() {
    scan(_restOfLine);
    final line = lastSpan!;
    scan(_lineEnding);
    return line;
  }
}

extension FileSpanScanExtension on FileSpan {
  /// This span with leading and trailing spaces and tabs removed.
  FileSpan trim() {
    final text = this.text;
    var start = 0;
    var end = text.length;
    while (start < end && _isSpaceOrTab(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isSpaceOrTab(text.codeUnitAt(end - 1))) {
      end--;
    }
    return subspan(start, end);
  }

  /// Non-whitespace tokens (`[^ \t]+`) within this span.
  List<FileSpan> scanTokens() {
    final scanner = SpanScanner.within(this);
    final tokens = <FileSpan>[];
    while (!scanner.isDone) {
      scanner.scan(_whitespace);
      if (scanner.scan(_nonWhitespace)) {
        tokens.add(scanner.lastSpan!);
      }
    }
    return tokens;
  }
}

bool _isSpaceOrTab(int unit) => unit == 0x20 || unit == 0x09;
