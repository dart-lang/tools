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

  test('invalid color arity and nonfinite components fail cleanly', () {
    expect(() => Color.css('rgba(10,20,30)'), throwsFormatException);
    expect(() => Color.css('rgb(NaN,20,30)'), throwsFormatException);
  });
}
