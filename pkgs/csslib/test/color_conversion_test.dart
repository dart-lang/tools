// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('ARGB channel extraction preserves all four channels', () {
    final rgba = Rgba.fromArgbValue(0x804080c0);
    expect(rgba.r, 0x40);
    expect(rgba.g, 0x80);
    expect(rgba.b, 0xc0);
    expect(rgba.a, closeTo(128 / 255, 0.00001));
    expect(rgba.argbValue, 0x804080c0);
    expect(rgba.toHexArgbString(), '804080c0');
  });

  test('RGBA fractional alpha is encoded into 8-bit ARGB', () {
    expect(Rgba(0xff, 0, 0, 0.5).argbValue, 0x80ff0000);
    expect(Rgba(0xff, 0, 0, 0).argbValue, 0x00ff0000);
    expect(Rgba(0xff, 0, 0, 1).argbValue, 0xffff0000);
  });

  test('ARGB round-trips retain each alpha byte, including 0x7f', () {
    expect(const Color.hex('7f112233').rgba.toHexArgbString(), '7f112233');
    expect(Hsla.fromArgbValue(0x7f808080).toHexArgbString(), '7f808080');
  });

  test('color string factories decode CSS colors only once', () {
    expect(Rgba.fromString('rgba(255,0,0,0.5)').toHexArgbString(), '80ff0000');
    expect(
      Hsla.fromString('rgba(255,0,0,0.5)').color.toHexArgbString(),
      '80ff0000',
    );
    expect(Rgba.fromString('rgb(255,0,0)').r, 255);
  });

  test('color string factories reject unsupported colors', () {
    expect(() => Rgba.fromString('foo'), throwsFormatException);
    expect(() => Hsla.fromString('foo'), throwsFormatException);
  });

  test('HSL to Color preserves hue and saturation', () {
    expect(Hsla(0, 1, 0.5, 1).color.toHexArgbString(), 'ffff0000');
    expect(Hsla(1 / 3, 1, 0.5).color.toHexArgbString(), '00ff00');
  });

  test('grayscale HSL conversion preserves alpha', () {
    final gray = Hsla.fromRgba(Rgba(128, 128, 128, 0.5));
    expect(gray.alpha, 0.5);
    expect(gray.color.toHexArgbString(), '80808080');
  });
}
