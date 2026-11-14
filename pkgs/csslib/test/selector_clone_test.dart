// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:test/test.dart';

void main() {
  test('parsed style sheet clones print identically and share no names', () {
    final sheet = parse('a:before, p::after, svg|rect, [lang|=he], '
        'li:nth-child(2n+1):not(.x) > b ~ #i + u, :host(.a) { color: red; }');
    final copy = sheet.clone();

    String printed(StyleSheet node) =>
        (CssPrinter()..visitTree(node, pretty: false)).toString();
    expect(printed(copy), printed(sheet));

    final originalNames = (_IdentifierCollector()..visitTree(sheet)).names;
    final clonedNames = (_IdentifierCollector()..visitTree(copy)).names;
    expect(clonedNames, hasLength(originalNames.length));
    expect(clonedNames.where(originalNames.contains), isEmpty);
  });
}

class _IdentifierCollector extends Visitor {
  final names = Set<Identifier>.identity();

  @override
  void visitIdentifier(Identifier node) => names.add(node);
}
