// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:code_builder/src/specs/expression.dart';
import 'package:test/test.dart';

import '../../common.dart';

void main() {
  useDartfmt();

  group('control expression', () {
    // general

    test('should insert a single body element', () {
      final expr = ControlExpression('test', body: [literal(1)]);
      expect(expr, equalsDart('test (1)'));
    });

    test('should insert multiple body elements with a separator', () {
      final expr = ControlExpression(
        'test',
        body: [literal(1), literal(2)],
        separator: ',',
      );
      expect(expr, equalsDart('test (1, 2)'));
    });

    test('should throw on multiple body elements w/o a separator', () {
      expect(
        () => ControlExpression(
          'test',
          body: [literal(1), literal(2)],
          // separator: null // default
        ).accept(DartEmitter()),
        throwsArgumentError,
      );
    });

    test('should not wrap body in parens if parenthesised is false', () {
      final expr = ControlExpression(
        'else',
        body: [refer('block')],
        parenthesised: false,
      );
      expect(expr, equalsDart('else block'));
    });

    test('should still insert separator for nulls in body', () {
      final expr = ControlExpression(
        'for',
        body: [null, refer('middle'), null],
        separator: ';',
      );
      expect(expr, equalsDart('for (; middle;)'));
    });

    test('should allow null/empty body and still emit control keyword', () {
      expect(const ControlExpression('while'), equalsDart('while'));
      expect(const ControlExpression('while', body: []), equalsDart('while'));
    });

    // specific constructors

    test('should emit an if statement', () {
      expect(
        ControlExpression.ifStatement(literal(1).equalTo(literal(2))),
        equalsDart('if (1 == 2)'),
      );
    });

    test('should emit an else statement', () {
      expect(ControlExpression.elseStatement(null), equalsDart('else'));
    });

    test('should emit an else if statement', () {
      expect(
        ControlExpression.elseStatement(
          ControlExpression.ifStatement(literal(false)),
        ),
        equalsDart('else if (false)'),
      );
    });

    test('should emit a for loop with all parts', () {
      expect(
        ControlExpression.forLoop(
          declareVar('i', type: refer('int')).assign(literal(0)),
          refer('i').lessThan(literal(10)),
          refer('i').operatorUnaryPostfixIncrement(),
        ),
        equalsDart('for (int i = 0; i < 10; i++)'),
      );
    });

    test('should emit a for loop with only init', () {
      expect(
        ControlExpression.forLoop(
          declareVar('i', type: refer('int')).assign(literal(0)),
          null,
          null,
        ),
        equalsDart('for (int i = 0;;)'),
      );
    });

    test('should emit a for loop with only condition', () {
      expect(
        ControlExpression.forLoop(null, refer('running'), null),
        equalsDart('for (; running;)'),
      );
    });

    test('should emit a for loop with only advance', () {
      expect(
        ControlExpression.forLoop(
          null,
          null,
          refer('i').operatorUnaryPostfixIncrement(),
        ),
        equalsDart('for (;; i++)'),
      );
    });

    test('should emit a for loop with all null body entries', () {
      expect(
        ControlExpression.forLoop(null, null, null),
        equalsDart('for (;;)'),
      );
    });

    test('should emit a for-in loop', () {
      expect(
        ControlExpression.forInLoop(refer('x'), refer('list')),
        equalsDart('for (x in list)'),
      );
    });

    test('should emit an await for loop', () {
      expect(
        ControlExpression.awaitForLoop(refer('x'), refer('stream')),
        equalsDart('await for (x in stream)'),
      );
    });

    test('should emit a while loop', () {
      expect(
        ControlExpression.whileLoop(literal(true)),
        equalsDart('while (true)'),
      );
    });

    test('should emit a do statement', () {
      expect(ControlExpression.doStatement, equalsDart('do'));
    });

    test('should emit a try statement', () {
      expect(ControlExpression.tryStatement, equalsDart('try'));
    });

    test('should emit a catch statement with only error', () {
      expect(ControlExpression.catchStatement('e'), equalsDart('catch (e)'));
    });

    test('should emit a catch statement with error and stacktrace', () {
      expect(
        ControlExpression.catchStatement('e', 's'),
        equalsDart('catch (e, s)'),
      );
    });

    test('should emit an on statement', () {
      expect(
        ControlExpression.onStatement(refer('FormatException')),
        equalsDart('on FormatException'),
      );
    });

    test('should emit an on statement with catch', () {
      expect(
        ControlExpression.onStatement(
          refer('FormatException'),
          ControlExpression.catchStatement('e'),
        ),
        equalsDart('on FormatException catch (e)'),
      );
    });

    test('should emit a finally statement', () {
      expect(ControlExpression.finallyStatement, equalsDart('finally'));
    });

    test('should emit a switch expression', () {
      final expression = ControlExpression.switchStatement(refer('object'));
      expect(expression, equalsDart('switch (object)'));
    });
  });

  group('expression control-flow', () {
    test('should emit a yield expression', () {
      final expr = refer('value').yielded;
      expect(expr, equalsDart('yield value'));
    });

    test('should emit a yield* expression', () {
      final expr = refer('stream').yieldStarred;
      expect(expr, equalsDart('yield* stream'));
    });

    test('should emit return statement', () {
      expect(ControlFlow.returnVoid, equalsDart('return'));
    });

    test('should emit break statement', () {
      expect(ControlFlow.breakVoid, equalsDart('break'));
    });

    test('should emit continue statement', () {
      expect(ControlFlow.continueVoid, equalsDart('continue'));
    });

    test('should emit labeled break statement', () {
      final expr = ControlFlow.breakLabel('loop1');
      expect(expr, equalsDart('break loop1'));
    });

    test('should emit labeled continue statement', () {
      final expr = ControlFlow.continueLabel('loop2');
      expect(expr, equalsDart('continue loop2'));
    });

    test('should emit a rethrow statement', () {
      expect(ControlFlow.rethrowVoid, equalsDart('rethrow'));
    });

    test('should emit an if-case expression', () {
      final expr = ControlFlow.ifCase(
        object: refer('value'),
        pattern: refer('int'),
      );
      expect(expr, equalsDart('value case int'));
    });

    test('should emit an if-case expression with a guard', () {
      final expr = ControlFlow.ifCase(
        object: refer('value'),
        pattern: refer('int'),
        guard: refer('value').greaterThan(literal(0)),
      );
      expect(expr, equalsDart('value case int when value > 0'));
    });

    test('should emit a collection-if expression', () {
      final expr = ControlFlow.collectionIf(
        condition: literalTrue,
        value: refer('value'),
      );

      expect(expr, equalsDart('if (true) value'));
    });

    test('should emit a collection-else expression', () {
      final expr = ControlFlow.collectionElse(value: refer('value'));

      expect(expr, equalsDart('else value'));
    });

    test('should emit a collection-else-if expression', () {
      final expr = ControlFlow.collectionElse(
        condition: literalTrue,
        value: refer('value'),
      );

      expect(expr, equalsDart('else if (true) value'));
    });

    test('should chain collection-if and else in list', () {
      Expression expr(bool includeStatic) => literalList([
        if (includeStatic) refer('always'),
        ControlFlow.collectionIf(condition: literalTrue, value: refer('value')),
        ControlFlow.collectionElse(value: refer('other')),
        if (includeStatic) refer('here'),
      ]);

      expect(expr(false), equalsDart('[if (true) value else other]'));
      expect(
        expr(true),
        equalsDart('[always, if (true) value else other, here, ]'),
      );
    });

    test('should chain collection-if and else in set', () {
      Expression expr(bool includeStatic) => literalSet({
        if (includeStatic) refer('always'),
        ControlFlow.collectionIf(condition: literalTrue, value: refer('value')),
        ControlFlow.collectionElse(
          condition: literalFalse,
          value: refer('thing'),
        ),
        ControlFlow.collectionElse(value: refer('other')),
        if (includeStatic) refer('here'),
      });

      expect(
        expr(false),
        equalsDart('{if (true) value else if (false) thing else other}'),
      );

      expect(
        expr(true),
        equalsDart('''
{always, if (true) value else if (false) thing else other, here, }'''),
      );
    });

    test('should chain collection-if and else in map', () {
      Expression expr(bool includeStatic) => literalMap({
        if (includeStatic) refer('always'): refer('here'),
        ControlFlow.collectionIf(
          condition: literalTrue,
          value: refer('key'),
        ): refer('value'),
        ControlFlow.collectionElse(
          condition: literalFalse,
          value: refer('key2'),
        ): refer('value2'),
        ControlFlow.collectionElse(value: refer('key3')): refer('value3'),
        if (includeStatic) refer('also'): refer('here'),
      });

      expect(
        expr(false),
        equalsDart('''
{if (true) key: value else if (false) key2: value2 else key3: value3}'''),
      );

      expect(
        expr(true),
        equalsDart('''
{always: here,
  if (true) key: value
  else if (false) key2: value2 
  else key3: value3,
  also: here,
}'''),
      );
    });

    test('should emit a collection-for loop', () {
      final expr = ControlFlow.collectionFor(
        value: refer('i'),
        initialize: declareVar('i').assign(literal(0)),
        condition: refer('i').lessThan(literal(5)),
        advance: refer('i').operatorUnaryPostfixIncrement(),
      );

      expect(expr, equalsDart('for (var i = 0; i < 5; i++) i'));
    });

    test('should emit a collection-for-in loop', () {
      final expr = ControlFlow.collectionForIn(
        value: refer('i'),
        identifier: declareFinal('i'),
        expression: refer('iterable'),
      );

      expect(expr, equalsDart('for (final i in iterable) i'));
    });

    test('should emit a list with nested collection-for/if', () {
      final expr = literalList([
        ControlFlow.collectionForIn(
          identifier: declareFinal('i'),
          expression: refer('iterable'),
          value: ControlFlow.collectionIf(
            condition: refer('i').property('something'),
            value: refer('i'),
          ),
        ),
      ]);

      expect(
        expr,
        equalsDart('[for (final i in iterable) if (i.something) i]'),
      );
    });

    test('should emit a set with nested for-in and if/else', () {
      final expr = literalSet({
        ControlFlow.collectionForIn(
          identifier: declareFinal('x'),
          expression: refer('items'),
          value: ControlFlow.collectionIf(
            condition: refer('x').property('valid'),
            value: refer('x'),
          ),
        ),
        ControlFlow.collectionElse(value: refer('fallback')),
      });

      expect(
        expr,
        equalsDart('{for (final x in items) if (x.valid) x else fallback}'),
      );
    });

    test('should emit a map wth nested for-in and if/else', () {
      final expr = literalMap({
        ControlFlow.collectionForIn(
          identifier: declareFinal('x'),
          expression: refer('items'),
          value: ControlFlow.collectionIf(
            condition: refer('x').property('valid'),
            value: refer('key'),
          ),
        ): refer('x'),
        ControlFlow.collectionElse(value: refer('key2')): refer(
          'fix',
        ).call([refer('x')]),
      });

      expect(
        expr,
        equalsDart('''
{for (final x in items) if (x.valid) key: x else key2: fix(x)}'''),
      );
    });

    test('should not chain else if used after static value', () {
      final expr = literalList([
        refer('static'),
        ControlFlow.collectionElse(value: refer('shouldNotChain')),
      ]);

      expect(expr, equalsDart('[static, else shouldNotChain, ]'));
    });

    test('should not chain for(in) if value is not chainable', () {
      final expr = literalList([
        ControlFlow.collectionForIn(
          identifier: declareFinal('x'),
          expression: refer('items'),
          value: refer('x'),
        ),
        ControlFlow.collectionElse(value: refer('shouldNotChain')),
      ]);

      expect(
        expr,
        equalsDart('[for (final x in items) x, else shouldNotChain, ]'),
      );
    });
  });

  group('expression helpers', () {
    test('should build a while loop with loopWhile', () {
      final expr = refer('isRunning').loopWhile((b) {
        b.addExpression(refer('tick').call([]));
      });

      expect(
        expr,
        equalsDart('''
while (isRunning) {
  tick();
}'''),
      );
    });

    test('should build a do-while loop with loopDoWhile', () {
      final expr = refer('conditionMet').loopDoWhile((b) {
        b.addExpression(refer('step').call([]));
      });

      expect(
        expr,
        equalsDart('''
do {
  step();
} while (conditionMet);'''),
      );
    });

    test('should build a for-in loop with loopForIn', () {
      final expr = refer('item').loopForIn(refer('items'), (b) {
        b.addExpression(refer('print').call([refer('item')]));
      });

      expect(
        expr,
        equalsDart('''
for (item in items) {
  print(item);
}'''),
      );
    });

    test('should build if statement with ifThen', () {
      final tree = refer('isTrue').ifThen((b) {
        b.addExpression(refer('execute').call([]));
      });

      expect(
        tree,
        equalsDart('''
if (isTrue) {
  execute();
}'''),
      );
    });

    test('should support ifThenReturn', () {
      final expr = refer('isTrue').ifThenReturn();

      expect(
        expr,
        equalsDart('''
if (isTrue) return'''),
      );
    });

    test('should support ifThenReturn with value', () {
      final expr = refer('isTrue').ifThenReturn(refer('value'));

      expect(
        expr,
        equalsDart('''
if (isTrue) return value'''),
      );
    });

    test('should support chaining', () {
      final tree = literal(1)
          .equalTo(literal(2))
          .ifThen((b) {
            b.addExpression(refer('print').call([literal('Bad')]));
          })
          .elseIf((b) {
            b
              ..condition = literal(2).equalTo(literal(2))
              ..body.addExpression(refer('print').call([literal('Good')]));
          })
          .orElse((b) {
            b.addExpression(refer('print').call([literal('What?')]));
          });

      expect(
        tree,
        equalsDart('''
if (1 == 2) {
  print('Bad');
} else if (2 == 2) {
  print('Good');
} else {
  print('What?');
}'''),
      );
    });
  });
}
