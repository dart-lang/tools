// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:test/test.dart';

void main() {
  test('many nested top-level rules flatten in original order', () {
    final css = StringBuffer();
    for (var i = 0; i < 500; i++) {
      css.write('.item$i { color: red; .child { width: 1px; } }');
    }

    final errors = <Message>[];
    final sheet = compile(css.toString(), errors: errors);
    expect(errors, isEmpty);
    expect(sheet.topLevels, hasLength(1000));
    final rules = sheet.topLevels.cast<RuleSet>();
    for (var i = 0; i < 500; i++) {
      final parent = rules[2 * i];
      final child = rules[2 * i + 1];
      expect(
        (CssPrinter()..visitTree(StyleSheet([parent], parent.span))).toString(),
        contains('.item$i'),
      );
      expect(
        (CssPrinter()..visitTree(StyleSheet([child], child.span))).toString(),
        contains('.item$i .child'),
      );
    }
  });

  test('at-rule nested expansions are kept in place', () {
    final errors = <Message>[];
    final sheet = compile(
      '.before { .nested { width: 1px; } } '
      '@media screen { .inside { .nested { width: 2px; } } } '
      '.after { .nested { width: 3px; } }',
      errors: errors,
    );
    expect(errors, isEmpty);
    final printer = CssPrinter()..visitTree(sheet);
    final output = printer.toString();
    expect(output, contains('@media'));
    expect(output, contains('.inside .nested'));
    expect(
        output.indexOf('.before .nested'), lessThan(output.indexOf('@media')));
    expect(output.indexOf('.after .nested'),
        greaterThan(output.indexOf('@media')));
  });
}
