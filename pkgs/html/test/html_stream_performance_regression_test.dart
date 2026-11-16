// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'dart:convert';

import 'package:html/dom_parsing.dart';
import 'package:html/src/html_input_stream.dart';
import 'package:test/test.dart';

void main() {
  group('HTML input stream normalization', () {
    test('unchanged Hebrew and ASCII content can be read in chunks', () {
      final stream = HtmlInputStream('שלום <b>עברית</b>');
      expect(stream.charsUntil1(0x3C), 'שלום ');
      expect(stream.char(), '<');
      expect(stream.charsUntil2(0x3E, 0x21), 'b');
      expect(stream.char(), '>');
      expect(stream.charsUntil3(0x3C, 0x26, 0x21), 'עברית');
      expect(stream.char(), '<');
    });

    test('decoded bytes can be read in chunks after reset', () {
      final stream = HtmlInputStream(utf8.encode('שלום <b>עברית</b>'));
      expect(stream.charsUntil1(0x3C), 'שלום ');
      stream.reset();
      expect(stream.charsUntil1(0x3C), 'שלום ');
      expect(stream.char(), '<');
      expect(stream.charsUntilAsciiLetter(true), 'b');
    });

    test('normalizes CRLF and lone CR identically after reset', () {
      final stream = HtmlInputStream('first\r\nsecond\rthird\n');
      expect(stream.charsUntil1(0x0), 'first\nsecond\nthird\n');
      stream.reset();
      expect(stream.charsUntil1(0x0), 'first\nsecond\nthird\n');
    });

    test('preserves surrogate pairs and replaces malformed surrogates', () {
      final stream = HtmlInputStream('א\uD83D\uDE00\uD800ב');
      expect(stream.charsUntil1(0x0), 'א\uD83D\uDE00\uFFFDב');
      expect(stream.errors, contains('invalid-codepoint'));
      stream.reset();
      expect(stream.charsUntil1(0x0), 'א\uD83D\uDE00\uFFFDב');
      expect(stream.errors, contains('invalid-codepoint'));
    });

    test('source spans keep the normalized source text', () {
      final stream = HtmlInputStream('אב\r\nגד', null, true, true);
      expect(stream.fileInfo!.getText(0, 5), 'אב\nגד');
    });
  });

  group('HTML serializer escaping', () {
    test('returns text unchanged without escapable characters', () {
      final plain = 'שלום עולם 😀';
      expect(htmlSerializeEscape(plain), same(plain));
    });

    test('escapes markup, ampersands and nonbreaking spaces', () {
      expect(htmlSerializeEscape('אב&< >\u00A0גד'), 'אב&amp;&lt; &gt;&nbsp;גד');
    });

    test('quotes are escaped only in attributes', () {
      expect(htmlSerializeEscape('a"b&c'), 'a"b&amp;c');
      expect(
          htmlSerializeEscape('a"b&c', attributeMode: true), 'a&quot;b&amp;c');
    });

    test('escapes adjacent and trailing characters', () {
      expect(htmlSerializeEscape('&&<>'), '&amp;&amp;&lt;&gt;');
      expect(htmlSerializeEscape('<'), '&lt;');
      expect(htmlSerializeEscape(''), '');
    });
  });
}
