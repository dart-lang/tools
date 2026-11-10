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

    test('numeric Color constructor preserves fractional alpha', () {
      expect(Color(0xff0000, 0).toHexArgbString(), '00ff0000');
      expect(Color(0xff0000, 0.5).toHexArgbString(), '80ff0000');
      expect(Color(0xff0000, 1).toHexArgbString(), 'ffff0000');
    });

    test('CSS short hex colors are expanded', () {
      expect(Color.css('#F00'), Color(0xff0000));
      expect(Color.css('#f008').toHexArgbString(), '88ff0000');
    });

    test('CSS eight-digit hex uses rrggbbaa order', () {
      expect(Color.css('#ff000080').toHexArgbString(), '80ff0000');
      expect(Color.css('  #FF0000  '), Color(0xff0000));
    });

    test('Color.css accepts named color keywords and transparent', () {
      expect(Color.css('red'), Color(0xff0000));
      expect(Color.css('ALICEBLUE'), Color(0xf0f8ff));
      expect(Color.css('transparent').toHexArgbString(), '00000000');
      expect(Color.css('Transparent').toHexArgbString(), '00000000');
    });

    test('Rgba and Hsla fromString keep the alpha channel in place', () {
      expect(Rgba.fromString('rgba(255, 0, 0, 0.5)').toHexArgbString(),
          '80ff0000');
      expect(Rgba.fromString('#ff000080').toHexArgbString(), '80ff0000');
      expect(Hsla.fromString('#ff000080').toHexArgbString(), '80ff0000');
    });

    test('empty and malformed CSS hex is rejected predictably', () {
      expect(() => Color.css(''), throwsFormatException);
      expect(() => Color.css('  '), throwsFormatException);
      expect(() => Color.css('#12'), throwsFormatException);
      expect(() => Color.css('#-12345'), throwsFormatException);
      expect(() => Color.css('# 12345'), throwsFormatException);
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
}
