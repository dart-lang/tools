// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('font CSS omits null and empty family lists', () {
    expect(const Font(size: 16).cssExpression, '16px');
    expect(const Font(size: 16, family: []).cssExpression, '16px');
    expect(
      const Font(size: 16, weight: FontWeight.bold).cssExpression,
      '700 16px',
    );
  });

  test('font CSS serializes multiple named families', () {
    expect(
      const Font(size: 16, family: ['Alef', 'serif']).cssExpression,
      '16px Alef, serif',
    );
  });

  test('line height is retained without explicit font weight', () {
    const font = Font(
      size: 16,
      lineHeight: LineHeight(24),
      family: ['Alef'],
    );
    expect(font.cssExpression, '16px/24px Alef');
    const withoutFamily = Font(size: 16, lineHeight: LineHeight(24));
    expect(withoutFamily.cssExpression, '16px/24px');
  });

  test('font CSS keeps weight and explicit line height', () {
    const font = Font(
      size: 16,
      weight: FontWeight.bold,
      lineHeight: LineHeight(24),
      family: ['Alef'],
    );
    expect(font.cssExpression, '700 16px/24px Alef');
  });

  test('unitless line height stays a multiplier', () {
    const font = Font(
      size: 16,
      lineHeight: LineHeight(1.5, inPixels: false),
      family: ['Alef'],
    );
    expect(font.cssExpression, '16px/1.5 Alef');
  });

  test('font CSS omits a missing size', () {
    expect(const Font(weight: FontWeight.bold).cssExpression, '700');
    expect(const Font(family: ['Alef']).cssExpression, 'Alef');
    expect(
      const Font(lineHeight: LineHeight(1.5, inPixels: false)).cssExpression,
      '',
    );
  });
}
