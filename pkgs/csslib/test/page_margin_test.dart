// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('left and right bottom page-margin names are distinct', () {
    const left = 'left-bottom';
    const right = 'right-bottom';
    expect(
      TokenKind.matchMarginDirectives(left, 0, left.length),
      TokenKind.MARGIN_DIRECTIVE_LEFTBOTTOM,
    );
    expect(
      TokenKind.matchMarginDirectives(right, 0, right.length),
      TokenKind.MARGIN_DIRECTIVE_RIGHTBOTTOM,
    );
  });
}
