// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('scaling keeps and scales absolute line heights', () {
    final families = ['Frank Ruhl', 'serif'];
    final original = Font(
      size: 12,
      family: families,
      weight: FontWeight.bold,
      lineHeight: const LineHeight(18),
    );
    final doubled = original.scale(2);

    expect(doubled.size, 24);
    expect(doubled.lineHeight!.height, 36);
    expect(doubled.lineHeight!.inPixels, isTrue);
    expect(doubled.lineHeightInPixels, 36);
    expect(doubled.weight, FontWeight.bold);
  });

  test('relative line height remains a ratio when the font scales', () {
    const original = Font(
      size: 10,
      lineHeight: LineHeight(1.5, inPixels: false),
    );
    final scaled = original.scale(2);

    expect(scaled.size, 20);
    expect(scaled.lineHeight!.height, 1.5);
    expect(scaled.lineHeight!.inPixels, isFalse);
    expect(scaled.lineHeightInPixels, 30);
    expect(original.lineHeightInPixels, 15);
  });

  test('scaling partial font families does not require font size', () {
    final family = <String>['Alef'];
    final original = Font(family: family);
    final scaled = original.scale(1.5);

    expect(scaled.size, isNull);
    expect(scaled.family, ['Alef']);

    const withLineHeight = Font(lineHeight: LineHeight(18));
    final scaledHeight = withLineHeight.scale(2);
    expect(scaledHeight.size, isNull);
    expect(scaledHeight.lineHeight!.height, 36);
  });
}
