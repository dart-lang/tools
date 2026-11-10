// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'dart:convert';

import 'package:html/parser.dart';
import 'package:html/src/encoding_parser.dart';
import 'package:test/test.dart';

void main() {
  group('numeric character references', () {
    test('decode decimal and hexadecimal Hebrew and astral code points', () {
      final fragment = parseFragment(
        '<p>&#1488;&#x5D1;&#1504; &#x1F600; &#x05D3;</p>',
      );
      expect(fragment.text, 'אבנ 😀 ד');
    });

    test('replace overflowing values with U+FFFD', () {
      final fragment = parseFragment(
        '<p>&#99999999999999999999999999999999999999;'
        '&#xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;</p>',
      );
      expect(fragment.text, '��');
    });

    test('decode a reference without a semicolon at EOF', () {
      expect(parseFragment('&#1488').text, 'א');
      expect(parseFragment('&#x5D1').text, 'ב');
    });

    test('keep text order across many references', () {
      final html = List.filled(300, '&#1488;').join();
      expect(parseFragment('<span>$html</span>').text,
          List.filled(300, 'א').join());
    });
  });

  group('named character references', () {
    test('match the longest entity name', () {
      final fragment = parseFragment(
        '<p>&notin; &not; &noti; &notit &amp; &copy; &ampx &unknown;</p>',
      );
      expect(fragment.text, '∉ ¬ ¬i; ¬it & © &x &unknown;');
    });

    test('match a legacy entity at EOF', () {
      expect(parseFragment('a&not').text, 'a¬');
      expect(parseFragment('a&noti').text, 'a¬i');
    });

    test('match a legacy entity followed by a surrogate pair', () {
      expect(parseFragment('&not😀').text, '¬😀');
    });

    test('keep legacy entities followed by alphanumerics in attributes', () {
      final fragment =
          parseFragment('<a title="&notit=1&copy;x&amp&noti">x</a>');
      expect(fragment.firstChild!.attributes['title'], '&notit=1©x&&noti');
    });
  });

  group('meta charset detection', () {
    test('skips comments and unrelated tags', () {
      const html = '<!-- <meta charset="ascii"> -->'
          '<html><head><title>x</title><meta charset="utf-8">'
          '</head></html>';
      expect(EncodingParser(utf8.encode(html)).getEncoding(), 'utf-8');
    });

    test('recognizes an uppercase declaration', () {
      const html = '<!DOCTYPE html><META CHARSET="UTF-8">';
      expect(EncodingParser(utf8.encode(html)).getEncoding(), 'utf-8');
    });

    test('ignores a truncated tag prefix at the end of the input', () {
      expect(EncodingParser(utf8.encode('<!--')).getEncoding(), isNull);
      expect(EncodingParser(utf8.encode('<me')).getEncoding(), isNull);
    });
  });
}
