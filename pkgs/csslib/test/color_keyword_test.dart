// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('rebeccapurple is a named color', () {
    expect(TokenKind.colorValue(TokenKind.matchColorName('rebeccapurple')!),
        0x663399);
    expect(TokenKind.colorValue(TokenKind.matchColorName('RebeccaPurple')!),
        0x663399);
  });
}
