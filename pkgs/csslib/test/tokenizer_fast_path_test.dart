// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  test('unescaped identifiers preserve names and !important', () {
    final errors = <Message>[];
    final sheet = parse(
      '.hebrew-שלום { font-family: FrankRuhl; color: red !important; }',
      errors: errors,
    );
    expect(errors, isEmpty);

    final declarations = (sheet.topLevels.single as RuleSet)
        .declarationGroup
        .declarations
        .cast<Declaration>();
    expect(declarations.map((declaration) => declaration.property), [
      'font-family',
      'color',
    ]);
    expect(declarations.last.important, isTrue);
  });

  test('escaped identifiers are decoded and keep their raw span', () {
    String decode(String css) {
      final token = Tokenizer(SourceFile.fromString(css), css, true).next();
      expect(token, isA<IdentifierToken>());
      expect(token.span.text, css);
      return (token as IdentifierToken).text;
    }

    expect(decode(r'ab\31 c'), 'ab1c');
    expect(decode(r'a\:b'), 'a:b');
    expect(decode(r'x\1F600'), 'x\u{1F600}');
    expect(decode(r'x\110000'), 'x�');
    expect(decode(r'שלום\5d'), 'שלום]');
  });
}
