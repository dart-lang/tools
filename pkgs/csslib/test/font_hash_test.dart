// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('hashCode is safe for partial and empty font properties', () {
    final fonts = [
      const Font(),
      const Font(size: 12),
      const Font(family: []),
      const Font(size: 12, family: []),
      const Font(size: 12, family: ['serif']),
    ];
    for (final font in fonts) {
      expect(() => font.hashCode, returnsNormally);
      expect(font.hashCode, isA<int>());
    }
  });

  test('equal fonts have equal hashes using the existing equality policy', () {
    final family = <String>['Alef', 'serif'];
    final first = Font(
      size: 16,
      family: family,
      weight: FontWeight.bold,
    );
    final second = Font(
      size: 16,
      family: family,
      weight: FontWeight.bold,
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect({first: 'found'}[second], 'found');
  });

  test('font hashes distinguish many equal-size distinct families', () {
    final fonts = List.generate(
      256,
      (i) => Font(size: 16, family: ['family-$i']),
    );
    final distinctHashes = fonts.map((font) => font.hashCode).toSet();
    expect(distinctHashes.length, greaterThan(200));
  });
}
