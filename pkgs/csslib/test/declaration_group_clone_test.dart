// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  test('cloning a group preserves terms and detaches its list', () {
    final group = GroupTerm(null)
      ..add(NumberTerm(2, '2', null))
      ..add(NumberTerm(5, '5', null));
    final copy = group.clone();

    expect((CssPrinter()..visitGroupTerm(copy)).toString(), '(2 5)');
    copy.add(NumberTerm(7, '7', null));
    expect((CssPrinter()..visitGroupTerm(copy)).toString(), '(2 5 7)');
    expect((CssPrinter()..visitGroupTerm(group)).toString(), '(2 5)');
  });

  test('IE7-prefixed declarations retain their flag on clone', () {
    final errors = <Message>[];
    final sheet = parse('a { *zoom: 1 !important; }', errors: errors);
    expect(errors, isEmpty);
    final rule = sheet.topLevels.single as RuleSet;
    final decl = rule.declarationGroup.declarations.single as Declaration;
    final copy = decl.clone();

    expect(decl.property, '*zoom');
    expect(copy.property, '*zoom');
    expect(copy.isIE7, isTrue);
    expect(copy.important, isTrue);

    final originalExpr = decl.expression as Expressions;
    final clonedExpr = copy.expression as Expressions;
    clonedExpr.expressions.clear();
    expect(originalExpr.expressions, hasLength(1));
  });

  test('cloned variable declarations preserve invalid-usage state', () {
    final span = SourceFile.fromString('var-foo').span(0, 7);
    final original = VarDefinition(Identifier('foo', span), null, span)
      ..badUsage = true;
    final copy = original.clone();

    expect(copy.badUsage, isTrue);
    copy.badUsage = false;
    expect(original.badUsage, isTrue);
  });

  test('included mixin declarations keep groups and IE7 flags', () {
    final errors = <Message>[];
    final sheet = compileCss('''
@mixin m {
  *zoom: 1;
  width: (2 5);
}
div { @include m; }''', errors: errors, opts: simpleOptions);

    expect(errors, isEmpty);
    expect(prettyPrint(sheet), '''
div {
  *zoom: 1;
  width: (2 5);
}''');
  });
}
