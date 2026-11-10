// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('named color lookup remains case insensitive', () {
    expect(TokenKind.colorValue(TokenKind.matchColorName('RED')!), 0xFF0000);
    expect(
      TokenKind.colorValue(TokenKind.matchColorName('aliceblue')!),
      0xF0F8FF,
    );
    expect(TokenKind.matchColorName('not-a-color'), isNull);
  });

  test('reverse color lookups preserve first canonical aliases', () {
    expect(TokenKind.hexToColorName(0x00FFFF), 'aqua');
    expect(TokenKind.hexToColorName(0xFF00FF), 'fuchsia');
    expect(TokenKind.hexToColorName(0xF0F8FF), 'aliceblue');
    expect(TokenKind.hexToColorName(0x010203), isNull);
  });
}
