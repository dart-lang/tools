// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:test/test.dart';

void main() {
  test('hex conversion retains color padding', () {
    expect(TokenKind.decimalToHex(0), '0');
    expect(TokenKind.decimalToHex(0, 6), '000000');
    expect(TokenKind.decimalToHex(15, 2), '0f');
    expect(TokenKind.decimalToHex(0xabcdef, 6), 'abcdef');
    expect(TokenKind.decimalToHex(0xffffff, 6), 'ffffff');
  });

  test('negative hex conversion terminates safely', () {
    expect(TokenKind.decimalToHex(-1), '-1');
    expect(TokenKind.decimalToHex(-255, 4), '-00ff');
  });

  test('named CSS colors still roundtrip through the parser and printer', () {
    final errors = <Message>[];
    final sheet = parse('a { color: aliceblue; }', errors: errors);
    expect(errors, isEmpty);
    expect((CssPrinter()..visitTree(sheet, pretty: true)).toString(),
        'a {\n  color: #f0f8ff;\n}');
  });
}
