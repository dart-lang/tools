// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  useDartfmt();

  group('for loop', () {
    test('emits a full for loop with body', () {
      final loop = ForLoop((b) {
        b
          ..initialize = declareVar('i', type: refer('int')).assign(literal(0))
          ..condition = refer('i').lessThan(literal(5))
          ..advance = refer('i').operatorUnaryPostfixIncrement()
          ..body.addExpression(refer('print').call([refer('i')]));
      });

      expect(
        loop,
        equalsDart('for (int i = 0; i < 5; i++) {\n  print(i);\n}'),
      );
    });

    test('emits a for loop with only init', () {
      final loop = ForLoop((b) {
        b.initialize = declareVar('i').assign(literal(1));
      });

      expect(loop, equalsDart('for (var i = 1;;) {}'));
    });

    test('emits a for loop with only condition', () {
      final loop = ForLoop((b) {
        b.condition = refer('keepGoing');
      });

      expect(loop, equalsDart('for (; keepGoing;) {}'));
    });

    test('emits a for loop with only advance', () {
      final loop = ForLoop((b) {
        b.advance = refer('i').operatorUnaryPostfixIncrement();
      });

      expect(loop, equalsDart('for (;; i++) {}'));
    });

    test('emits a for loop with label', () {
      final loop = ForLoop((b) {
        b.label = 'outer';
      });

      expect(loop, equalsDart('outer: for (;;) {}'));
    });
  });

  group('for-in loop', () {
    test('emits a basic for-in loop', () {
      final loop = ForInLoop((b) {
        b
          ..variable = refer('item')
          ..object = refer('items');
      });

      expect(loop, equalsDart('for (item in items) {}'));
    });

    test('emits a labeled for-in loop', () {
      final loop = ForInLoop((b) {
        b
          ..label = 'each'
          ..variable = refer('item')
          ..object = refer('items');
      });

      expect(loop, equalsDart('each: for (item in items) {}'));
    });

    test('emits an async for-in loop', () {
      final loop = ForInLoop((b) {
        b
          ..async = true
          ..variable = refer('event')
          ..object = refer('stream');
      });

      expect(loop, equalsDart('await for (event in stream) {}'));
    });
  });

  group('while loop', () {
    test('emits a basic while loop', () {
      final loop = WhileLoop((b) {
        b.condition = refer('running');
      });

      expect(loop, equalsDart('while (running) {}'));
    });

    test('emits a labeled while loop', () {
      final loop = WhileLoop((b) {
        b
          ..label = 'mainLoop'
          ..condition = refer('true');
      });

      expect(loop, equalsDart('mainLoop: while (true) {}'));
    });

    test('emits a do-while loop', () {
      final loop = WhileLoop((b) {
        b
          ..doWhile = true
          ..condition = refer('keepGoing')
          ..body.addExpression(
            refer('process').call([]),
          );
      });

      expect(
        loop,
        equalsDart('do {\n  process();\n} while (keepGoing);'),
      );
    });
  });
}
