// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  group('css', () {
    test('rgb', () {
      final color = Color.css('rgb(0, 0, 255)');
      expect(color, equals(Color(0x0000FF)));
    });

    test('rgba', () {
      final color = Color.css('rgba(0, 0, 255, 1.0)');
      expect(color, equals(Color.createRgba(0, 0, 255, 1.0)));
    });
  });

  group('named colors', () {
    test('constants match the CSS values', () {
      expect(Color.aliceBlue, equals(Color(0xF0F8FF)));
      expect(Color.antiqueWhite, equals(Color(0xFAEBD7)));
      expect(Color.peru, equals(Color(0xCD853F)));
    });

    test('aliceblue is parsed as #f0f8ff', () {
      final stylesheet = parseCss('a { color: aliceblue; }');
      expect(prettyPrint(stylesheet), 'a {\n  color: #f0f8ff;\n}');
    });
  });

  group('named color lookup', () {
    test('remains case insensitive', () {
      expect(TokenKind.colorValue(TokenKind.matchColorName('RED')!), 0xFF0000);
      expect(
        TokenKind.colorValue(TokenKind.matchColorName('aliceblue')!),
        0xF0F8FF,
      );
      expect(TokenKind.matchColorName('not-a-color'), isNull);
    });

    test('reverse lookups preserve first canonical aliases', () {
      expect(TokenKind.hexToColorName(0x00FFFF), 'aqua');
      expect(TokenKind.hexToColorName(0xFF00FF), 'fuchsia');
      expect(TokenKind.hexToColorName(0xF0F8FF), 'aliceblue');
      expect(TokenKind.hexToColorName(0x010203), isNull);
    });
  });
}
