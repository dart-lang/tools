// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('HSL function converts degrees and percentages', () {
    expect(Color.css('hsl(0, 100%, 50%)'), Color(0xff0000));
    expect(Color.css('hsl(120, 100%, 50%)'), Color(0x00ff00));
    expect(Color.css('hsl(240, 100%, 50%)'), Color(0x0000ff));
  });

  test('HSL hue wraps and respects CSS angle units', () {
    expect(Color.css('hsl(480deg,100%,50%)'), Color(0x00ff00));
    expect(Color.css('hsl(-120deg,100%,50%)'), Color(0x0000ff));
    expect(Color.css('hsl(0.5turn,100%,50%)'), Color(0x00ffff));
    expect(Color.css('hsl(100grad,100%,50%)'), Color(0x80ff00));
    expect(Color.css('hsl(1.5707963267948966rad,100%,50%)'), Color(0x80ff00));
    expect(Color.css('HSL(120DEG,100%,50%)'), Color(0x00ff00));
  });

  test('HSLA parses fractional and percentage alpha', () {
    expect(
      Color.css('hsla(240,100%,50%,0.5)').toHexArgbString(),
      '800000ff',
    );
    expect(
      Color.css('hsla(240,100%,50%,50%)').toHexArgbString(),
      '800000ff',
    );
  });

  test('RGB and RGBA accept percentages', () {
    expect(Color.css('rgb(100%,0%,0%)'), Color(0xff0000));
    expect(
      Color.css('rgba(100%,0%,0%,50%)').toHexArgbString(),
      '80ff0000',
    );
  });

  test('invalid color arity and nonfinite components fail cleanly', () {
    expect(() => Color.css('rgba(10,20,30)'), throwsFormatException);
    expect(() => Color.css('rgb(NaN,20,30)'), throwsFormatException);
  });

  test('component errors report the whole color as their source', () {
    expect(
      () => Color.css('rgb(1x,20,30)'),
      throwsA(isA<FormatException>()
          .having((e) => e.source, 'source', 'rgb(1x,20,30)')),
    );
  });
}
