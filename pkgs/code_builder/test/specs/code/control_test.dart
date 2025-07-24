// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Tests for ControlExpression

import 'package:code_builder/code_builder.dart';
import 'package:code_builder/src/specs/expression.dart';
import 'package:test/test.dart';

import '../../common.dart';

void main() {
  useDartfmt();

  test(
    'should emit an if statement',
    () {
      expect(ControlExpression.ifStatement(literal(1).equalTo(literal(2))),
          equalsDart('if (1 == 2)'));
    },
  );

  test(
    'should emit an else statement',
    () {
      expect(ControlExpression.elseStatement, equalsDart('else'));
    },
  );

  test(
    'should emit an else-if statement',
    () {
      expect(ControlExpression.elseIfStatement(literal(true)),
          equalsDart('else if (true)'));
    },
  );

  test(
    'should emit a for loop with all parts',
    () {
      expect(
        ControlExpression.forLoop(
          declareVar('i', type: refer('int')).assign(literal(0)),
          refer('i').lessThan(literal(10)),
          refer('i').operatorUnaryPostfixIncrement(),
        ),
        equalsDart('for (int i = 0; i < 10; i++)'),
      );
    },
  );

  test(
    'should emit a for loop with only init',
    () {
      expect(
        ControlExpression.forLoop(
          declareVar('i', type: refer('int')).assign(literal(0)),
          null,
          null,
        ),
        equalsDart('for (int i = 0;;)'),
      );
    },
  );

  test(
    'should emit a for loop with only condition',
    () {
      expect(
        ControlExpression.forLoop(
          null,
          refer('running'),
          null,
        ),
        equalsDart('for (; running;)'),
      );
    },
  );

  test(
    'should emit a for loop with only advance',
    () {
      expect(
        ControlExpression.forLoop(
          null,
          null,
          refer('i').operatorUnaryPostfixIncrement(),
        ),
        equalsDart('for (;; i++)'),
      );
    },
  );

  test(
    'should emit a for loop with all null body entries',
    () {
      expect(
        ControlExpression.forLoop(null, null, null),
        equalsDart('for (;;)'),
      );
    },
  );

  test(
    'should emit a for-in loop',
    () {
      expect(
        ControlExpression.forInLoop(refer('x'), refer('list')),
        equalsDart('for (x in list)'),
      );
    },
  );

  test(
    'should emit an await for loop',
    () {
      expect(
        ControlExpression.awaitForLoop(refer('x'), refer('stream')),
        equalsDart('await for (x in stream)'),
      );
    },
  );

  test(
    'should emit a while loop',
    () {
      expect(
        ControlExpression.whileLoop(literal(true)),
        equalsDart('while (true)'),
      );
    },
  );

  test(
    'should emit a do statement',
    () {
      expect(ControlExpression.doStatement, equalsDart('do'));
    },
  );

  test(
    'should emit a break statement without label',
    () {
      expect(ControlExpression.breakStatement(), equalsDart('break'));
    },
  );

  test(
    'should emit a break statement with label',
    () {
      expect(
          ControlExpression.breakStatement('loop1'), equalsDart('break loop1'));
    },
  );

  test(
    'should emit a continue statement without label',
    () {
      expect(ControlExpression.continueStatement(), equalsDart('continue'));
    },
  );

  test(
    'should emit a continue statement with label',
    () {
      expect(ControlExpression.continueStatement('loop1'),
          equalsDart('continue loop1'));
    },
  );

  test(
    'should emit a try statement',
    () {
      expect(ControlExpression.tryStatement, equalsDart('try'));
    },
  );

  test(
    'should emit a catch statement with only error',
    () {
      expect(ControlExpression.catchStatement(refer('e')),
          equalsDart('catch (e)'));
    },
  );

  test(
    'should emit a catch statement with error and stacktrace',
    () {
      expect(ControlExpression.catchStatement(refer('e'), refer('s')),
          equalsDart('catch (e, s)'));
    },
  );

  test(
    'should emit an on statement',
    () {
      expect(ControlExpression.onStatement(refer('FormatException')),
          equalsDart('on FormatException'));
    },
  );

  test(
    'should emit a finally statement',
    () {
      expect(ControlExpression.finallyStatement, equalsDart('finally'));
    },
  );
}
