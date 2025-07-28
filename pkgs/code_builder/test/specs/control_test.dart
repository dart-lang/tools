// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  useDartfmt();

  group('for loop', () {
    test('should emit a full for loop with body', () {
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

    test('should emit a for loop with only init', () {
      final loop = ForLoop((b) {
        b.initialize = declareVar('i').assign(literal(1));
      });

      expect(loop, equalsDart('for (var i = 1;;) {}'));
    });

    test('should emit a for loop with only condition', () {
      final loop = ForLoop((b) {
        b.condition = refer('keepGoing');
      });

      expect(loop, equalsDart('for (; keepGoing;) {}'));
    });

    test('should emit a for loop with only advance', () {
      final loop = ForLoop((b) {
        b.advance = refer('i').operatorUnaryPostfixIncrement();
      });

      expect(loop, equalsDart('for (;; i++) {}'));
    });

    test('should emit a for loop with label', () {
      final loop = ForLoop((b) {
        b.label = 'outer';
      });

      expect(loop, equalsDart('outer: for (;;) {}'));
    });
  });

  group('for-in loop', () {
    test('should emit a basic for-in loop', () {
      final loop = ForInLoop((b) {
        b
          ..variable = refer('item')
          ..object = refer('items');
      });

      expect(loop, equalsDart('for (item in items) {}'));
    });

    test('should emit a labeled for-in loop', () {
      final loop = ForInLoop((b) {
        b
          ..label = 'each'
          ..variable = refer('item')
          ..object = refer('items');
      });

      expect(loop, equalsDart('each: for (item in items) {}'));
    });

    test('should emit an async for-in loop', () {
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
    test('should emit a basic while loop', () {
      final loop = WhileLoop((b) {
        b.condition = refer('running');
      });

      expect(loop, equalsDart('while (running) {}'));
    });

    test('should emit a labeled while loop', () {
      final loop = WhileLoop((b) {
        b
          ..label = 'mainLoop'
          ..condition = refer('true');
      });

      expect(loop, equalsDart('mainLoop: while (true) {}'));
    });

    test('should emit a do-while loop', () {
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

    test('should emit a labeled do-while loop', () {
      final loop = WhileLoop((b) {
        b
          ..doWhile = true
          ..label = 'mainLoop'
          ..condition = refer('keepGoing')
          ..body.addExpression(
            refer('process').call([]),
          );
      });

      expect(
        loop,
        equalsDart('mainLoop: do {\n  process();\n} while (keepGoing);'),
      );
    });
  });

  group('condition', () {
    test('should emit a basic if condition', () {
      final condition = Condition((b) {
        b
          ..condition = refer('x').equalTo(literal(0))
          ..body.addExpression(refer('print').call([literal('zero')]));
      });

      expect(
        condition,
        equalsDart('if (x == 0) {\n  print(\'zero\');\n}'),
      );

      expect(
        condition.asTree,
        equalsDart('if (x == 0) {\n  print(\'zero\');\n}'),
      );
    });

    test('should emit a condition with null body', () {
      final condition = Condition((b) {
        b.condition = literal(true);
      });

      expect(
        condition,
        equalsDart('if (true) {}'),
      );
    });

    test('should emit an else condition', () {
      final original = Condition((b) {
        b.body.addExpression(refer('print').call([literal('fallback')]));
      });

      final elseBlock = original.asElse;

      expect(
        elseBlock,
        equalsDart('else {\n  print(\'fallback\');\n}'),
      );
    });

    test('should emit an else-if condition', () {
      final original = Condition((b) {
        b
          ..condition = refer('value').greaterThan(literal(10))
          ..body.addExpression(refer('log').call([literal('big')]));
      });

      final elseIf = original.asElse;

      expect(
        elseIf,
        equalsDart('else if (value > 10) {\n  log(\'big\');\n}'),
      );
    });

    test('should throw if condition is null', () {
      expect(
        () => Condition((b) {}).accept(DartEmitter()),
        throwsArgumentError,
      );
    });

    test('should emit an if-case condition', () {
      final condition = Condition((b) {
        b.ifCase(
          object: refer('value'),
          pattern: refer('int'),
        );
        b.body.addExpression(refer('print').call([literal('int')]));
      });

      expect(
        condition,
        equalsDart('if (value case int) {\n  print(\'int\');\n}'),
      );
    });

    test('should emit an if-case with guard clause', () {
      final condition = Condition((b) {
        b.ifCase(
          object: refer('value'),
          pattern: refer('int'),
          guard: refer('value').greaterThan(literal(0)),
        );
        b.body.addExpression(refer('print').call([literal('positive')]));
      });

      expect(
        condition,
        equalsDart(
            'if (value case int when value > 0) {\n  print(\'positive\');\n}'),
      );
    });
  });

  group('if tree', () {
    test('should emit a single if block', () {
      final tree = IfTree((b) {
        b.add(Condition((b) {
          b
            ..condition = refer('x').equalTo(literal(1))
            ..body.addExpression(refer('print').call([literal('one')]));
        }));
      });

      expect(
        tree,
        equalsDart('if (x == 1) {\n  print(\'one\');\n}'),
      );
    });

    test('should emit if-else if-else chain', () {
      final tree = IfTree((b) {
        b
          ..add(Condition((b) {
            b
              ..condition = refer('x').equalTo(literal(1))
              ..body.addExpression(refer('print').call([literal('one')]));
          }))
          ..add(Condition((b) {
            b
              ..condition = refer('x').equalTo(literal(2))
              ..body.addExpression(refer('print').call([literal('two')]));
          }))
          ..orElse((body) {
            body.addExpression(refer('print').call([literal('other')]));
          });
      });

      expect(
        tree,
        equalsDart('''
if (x == 1) {
  print('one');
} else if (x == 2) {
  print('two');
} else {
  print('other');
}'''),
      );
    });

    test('should support IfTree.of constructor', () {
      final tree = IfTree.of([
        Condition((b) {
          b
            ..condition = refer('ready')
            ..body.addExpression(refer('start').call([]));
        }),
        Condition((b) {
          b.body.addExpression(refer('exit').call([]));
        }),
      ]);

      expect(
        tree,
        equalsDart('''
if (ready) {
  start();
} else {
  exit();
}'''),
      );
    });

    test('should support withCondition', () {
      final base = IfTree((b) {
        b.add(Condition((b) {
          b
            ..condition = refer('a')
            ..body.addExpression(refer('doA').call([]));
        }));
      });

      final extended = base.withCondition(Condition((b) {
        b
          ..condition = refer('b')
          ..body.addExpression(refer('doB').call([]));
      }));

      expect(
        extended,
        equalsDart('''
if (a) {
  doA();
} else if (b) {
  doB();
}'''),
      );
    });

    test('should support elseIf', () {
      final tree = IfTree((b) {
        b.add(Condition((b) {
          b
            ..condition = refer('loggedIn')
            ..body.addExpression(refer('showDashboard').call([]));
        }));
      }).elseIf((b) {
        b
          ..condition = refer('isGuest')
          ..body.addExpression(refer('showGuest').call([]));
      });

      expect(
        tree,
        equalsDart('''
if (loggedIn) {
  showDashboard();
} else if (isGuest) {
  showGuest();
}'''),
      );
    });

    test('should support orElse', () {
      final tree = IfTree((b) {
        b.add(Condition((b) {
          b
            ..condition = refer('ready')
            ..body.addExpression(refer('start').call([]));
        }));
      }).orElse((body) {
        body.addExpression(refer('log').call([literal('not ready')]));
      });

      expect(
        tree,
        equalsDart('''
if (ready) {
  start();
} else {
  log('not ready');
}'''),
      );
    });

    test('should support empty IfTree', () {
      final tree = IfTree((b) {});
      expect(tree.blocks, isEmpty);
    });
  });

  group('if tree builder', () {
    test('should support add', () {
      final tree = IfTree((b) {
        final condition = Condition((b) {
          b
            ..condition = refer('ok')
            ..body.addExpression(refer('run').call([]));
        });
        b.add(condition);
      });

      expect(tree, equalsDart('if (ok) {\n  run();\n}'));
    });

    test('should support addAll', () {
      final conditions = [
        Condition((b) {
          b
            ..condition = refer('x > 0')
            ..body.addExpression(refer('handlePositive').call([]));
        }),
        Condition((b) {
          b.body.addExpression(refer('handleZeroOrNegative').call([]));
        }),
      ];

      final tree = IfTree((b) {
        b.addAll(conditions);
      });

      expect(
        tree,
        equalsDart('''
if (x > 0) {
  handlePositive();
} else {
  handleZeroOrNegative();
}'''),
      );
    });

    test('should support orElse', () {
      final tree = IfTree((b) {
        b
          ..add(Condition((b) {
            b
              ..condition = refer('a')
              ..body.addExpression(refer('doA').call([]));
          }))
          ..orElse((body) {
            body.addExpression(refer('fallback').call([]));
          });
      });

      expect(
        tree,
        equalsDart('''
if (a) {
  doA();
} else {
  fallback();
}'''),
      );
    });

    test('should support orElseThrow', () {
      final tree = IfTree((b) {
        b
          ..add(Condition((b) {
            b
              ..condition = refer('valid')
              ..body.addExpression(refer('process').call([]));
          }))
          ..orElseThrow(refer('UnsupportedError')
              .newInstance([literal('Invalid input')]));
      });

      expect(
        tree,
        equalsDart('''
if (valid) {
  process();
} else {
  throw UnsupportedError('Invalid input');
}'''),
      );
    });

    test('should support ifThen', () {
      final tree = IfTree((b) {
        b.ifThen((cond) {
          cond
            ..condition = refer('ready')
            ..body.addExpression(refer('init').call([]));
        });
      });

      expect(tree, equalsDart('if (ready) {\n  init();\n}'));
    });
  });

  group('catch block', () {
    test('should emit catch with default exception name', () {
      final catchBlock = CatchBlock((b) => b..body.addExpression(literal(1)));
      expect(catchBlock, equalsDart('catch (e) {\n  1;\n}'));
    });

    test('should emit catch with custom exception name', () {
      final catchBlock = CatchBlock((b) => b
        ..exception = 'err'
        ..body.addExpression(literal(2)));
      expect(catchBlock, equalsDart('catch (err) {\n  2;\n}'));
    });

    test('should emit catch with exception and stacktrace', () {
      final catchBlock = CatchBlock((b) => b
        ..exception = 'e'
        ..stacktrace = 's'
        ..body.addExpression(refer('log').call([refer('s')])));
      expect(catchBlock, equalsDart('catch (e, s) {\n  log(s);\n}'));
    });

    test('should emit on-type catch block', () {
      final catchBlock = CatchBlock((b) => b
        ..type = refer('FormatException')
        ..exception = 'e'
        ..stacktrace = 's'
        ..body.addExpression(refer('print').call([refer('e')])));
      expect(
        catchBlock,
        equalsDart('on FormatException catch (e, s) {\n  print(e);\n}'),
      );
    });
  });

  group('try-catch', () {
    test('should throw if no catch handlers are defined', () {
      expect(() => TryCatch((b) => b.body.addExpression(literal(1))),
          throwsArgumentError);
    });

    test('should emit try/catch block', () {
      final block = TryCatch((b) {
        b.body.addExpression(refer('mightFail').call([]));
        b.addCatch(
            (cb) => cb.body.addExpression(refer('handleError').call([])));
      });

      expect(
        block,
        equalsDart('''
try {
  mightFail();
} catch (e) {
  handleError();
}'''),
      );
    });

    test('should emit try/on-type/catch with finally', () {
      final block = TryCatch((b) {
        b.body.addExpression(refer('mightFail').call([]));
        b
          ..addCatch((cb) => cb
            ..type = refer('HttpException')
            ..exception = 'e'
            ..stacktrace = 's'
            ..body.addExpression(refer('print').call([refer('s')])))
          ..addFinally((fb) => fb.addExpression(refer('cleanup').call([])));
      });

      expect(
        block,
        equalsDart('''
try {
  mightFail();
} on HttpException catch (e, s) {
  print(s);
} finally {
  cleanup();
}'''),
      );
    });

    test('should emit try with multiple catch clauses', () {
      final block = TryCatch((b) {
        b
          ..body.addExpression(refer('foo').call([]))
          ..addCatch((cb) => cb
            ..type = refer('FormatException')
            ..exception = 'e1'
            ..body.addExpression(refer('handleFormat').call([])))
          ..addCatch((cb) => cb
            ..type = refer('SocketException')
            ..exception = 'e2'
            ..body.addExpression(refer('handleSocket').call([])))
          ..addCatch(
            (cb) => cb.body.addExpression(ControlFlow.rethrowVoid),
          );
      });

      expect(
        block,
        equalsDart('''
try {
  foo();
} on FormatException catch (e1) {
  handleFormat();
} on SocketException catch (e2) {
  handleSocket();
} catch (e) {
  rethrow;
}'''),
      );
    });
  });

  group('try-catch builder', () {
    test('addCatch should append to handlers', () {
      final builder = TryCatchBuilder();
      builder.body.addExpression(literal(0));
      builder.addCatch((cb) => cb.body.addExpression(literal(1)));

      final result = builder.build();
      expect(result.handlers, hasLength(1));
      expect(result, equalsDart('''
try {
  0;
} catch (e) {
  1;
}
'''));
    });

    test('addFinally should update handleAll', () {
      final builder = TryCatchBuilder()
        ..body.addExpression(literal(0))
        ..addCatch((cb) => cb.body.addExpression(literal(1)))
        ..addFinally((fb) => fb.addExpression(refer('done')));

      final result = builder.build();
      expect(result.handleAll, isNotNull);
      expect(result, equalsDart('''
try {
  0;
} catch (e) {
  1;
} finally {
  done;
}
'''));
    });
  });

  group('switch statement', () {
    test('should emit basic case with single statement body', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('x');
        b.cases.add(Case((cb) {
          cb
            ..pattern = literal(1)
            ..body = refer('print').call([literal('one')]).statement;
        }));
      });

      expect(
        stmt,
        equalsDart('''
switch (x) {
  case 1:
    print('one');
}'''),
      );
    });

    test('should emit multiline case', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('x');
        b.cases.add(Case((cb) {
          cb
            ..pattern = literal(1)
            ..body = Block.of([
              refer('print').call([literal('one')]).statement,
              refer('print').call([literal('two')]).statement,
              ControlFlow.breakVoid.statement,
            ]);
        }));
      });

      expect(
        stmt,
        equalsDart('''
switch (x) {
  case 1:
    print('one');
    print('two');
    break;
}'''),
      );
    });

    test('should emit multiple cases with separate bodies', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('val');
        b.cases.addAll([
          Case((cb) => cb
            ..pattern = literal(1)
            ..body = refer('print').call([literal('first')]).statement),
          Case((cb) => cb
            ..pattern = literal(2)
            ..body = refer('print').call([literal('second')]).statement),
        ]);
      });

      expect(
        stmt,
        equalsDart('''
switch (val) {
  case 1:
    print('first');
  case 2:
    print('second');
}'''),
      );
    });

    test('should emit fallthrough with null body', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('foo');
        b.cases.addAll([
          Case((cb) => cb
            ..pattern = literal(0)
            ..body = null),
          Case((cb) => cb
            ..pattern = literal(1)
            ..body = refer('handleOne').call([]).statement),
        ]);
      });

      expect(
        stmt,
        equalsDart('''
switch (foo) {
  case 0:
  case 1:
    handleOne();
}'''),
      );
    });

    test('should emit case with guard clause', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('value');
        b.cases.add(Case((cb) => cb
          ..pattern = literal(5)
          ..guard = refer('value').greaterThan(literal(2))
          ..body = refer('print').call([literal('guarded')]).statement));
      });

      expect(
        stmt,
        equalsDart('''
switch (value) {
  case 5 when value > 2:
    print('guarded');
}'''),
      );
    });

    test('should emit case with label and body', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('n');
        b.cases.add(Case((cb) => cb
          ..label = 'start'
          ..pattern = literal(0)
          ..body = refer('begin').call([]).statement));
      });

      expect(
        stmt,
        equalsDart('''
switch (n) {
  start:
  case 0:
    begin();
}'''),
      );
    });

    test('should emit labeled case fallthrough to another', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('step');
        b.cases.addAll([
          Case((cb) => cb
            ..label = 'init'
            ..pattern = literal('A')
            ..body = null),
          Case((cb) => cb
            ..pattern = literal('B')
            ..body = refer('continueProcess').call([]).statement),
        ]);
      });

      expect(
        stmt,
        equalsDart('''
switch (step) {
  init:
  case 'A':
  case 'B':
    continueProcess();
}'''),
      );
    });

    test('should emit default case', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('cmd');
        b.cases
            .add(Case.any(refer('log').call([literal('default')]).statement));
      });

      expect(
        stmt,
        equalsDart('''
switch (cmd) {
  default:
    log('default');
}'''),
      );
    });

    test('should emit labeled default case', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('cmd');
        b.cases.add(Case.any(refer('log').call([literal('default')]).statement,
            label: 'label'));
      });

      expect(
        stmt,
        equalsDart('''
switch (cmd) {
  label:
  default:
    log('default');
}'''),
      );
    });

    test('should emit wildcard case', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('cmd');
        b.cases.add(Case((cb) => cb
          ..pattern = Expression.wildcard
          ..body = refer('log').call([literal('wildcard')]).statement));
      });

      expect(
        stmt,
        equalsDart('''
switch (cmd) {
  case _:
    log('wildcard');
}'''),
      );
    });

    test('should emit full mixed case block with guard, label, and default',
        () {
      final stmt = SwitchStatement((b) {
        b.value = refer('x');
        b.cases.addAll([
          Case((cb) => cb..pattern = literal(-1)),
          Case((cb) => cb
            ..pattern = literal(0)
            ..body = ControlFlow.continueLabel('other').statement),
          Case((cb) => cb
            ..pattern = literal(1)
            ..guard = refer('x').equalTo(literal(1))
            ..body = refer('handleOne').call([]).statement),
          Case((cb) => cb
            ..pattern = literal(2)
            ..label = 'other'
            ..body = Block.of([
              refer('printWarning').call([]).statement,
              refer('handleNotOne').call([]).statement,
            ])),
          Case.any(refer('defaultCase').call([]).statement),
        ]);
      });

      expect(
        stmt,
        equalsDart('''
switch (x) {
  case -1:
  case 0:
    continue other;
  case 1 when x == 1:
    handleOne();
  other:
  case 2:
    printWarning();
    handleNotOne();
  default:
    defaultCase();
}'''),
      );
    });
  });

  group('switch expression', () {
    final matchValue = refer('value');

    test('should generate a single-case switch expression', () {
      final expr = SwitchExpression((b) => b
        ..value = matchValue
        ..cases.add(Case((b) => b
          ..pattern = refer('1')
          ..body = refer("'one'"))));

      expect(
        expr,
        equalsDart('''
          switch (value) {
            1 => 'one',
          }
        '''),
      );
    });

    test('should support guard expressions in cases', () {
      final expr = SwitchExpression((b) => b
        ..value = matchValue
        ..cases.add(Case((b) => b
          ..pattern = refer('x')
          ..guard = refer('x > 5')
          ..body = refer("'greater than 5'"))));

      expect(
        expr,
        equalsDart('''
          switch (value) {
            x when x > 5 => 'greater than 5',
          }
        '''),
      );
    });

    test('should ignore label in switch expressions', () {
      final expr = SwitchExpression((b) => b
        ..value = matchValue
        ..cases.add(Case((b) => b
          ..pattern = refer('2')
          ..label = 'ignoredLabel'
          ..body = refer("'two'"))));

      expect(
        expr,
        equalsDart('''
          switch (value) {
            2 => 'two',
          }
        '''),
      );
    });

    test('should generate wildcard case using Case.any', () {
      final expr = SwitchExpression((b) => b
        ..value = matchValue
        ..cases.add(Case.any(refer("'default'"))));

      expect(
        expr,
        equalsDart('''
          switch (value) {
            _ => 'default',
          }
        '''),
      );
    });

    test('should throw if case body is null', () {
      expect(
        () => SwitchExpression((b) => b
              ..value = matchValue
              ..cases.add(Case((b) => b..pattern = refer('1'))))
            .accept(DartEmitter()),
        throwsArgumentError,
      );
    });

    test('should generate multiple cases with mixed guards and default', () {
      final expr = SwitchExpression((b) => b
        ..value = matchValue
        ..cases.addAll([
          Case((b) => b
            ..pattern = refer('1')
            ..body = refer("'one'")),
          Case((b) => b
            ..pattern = refer('2')
            ..guard = refer('checkTwo()')
            ..body = refer("'two'")),
          Case.any(refer("'fallback'")),
        ]));

      expect(
        expr,
        equalsDart('''
          switch (value) {
            1 => 'one',
            2 when checkTwo() => 'two',
            _ => 'fallback',
          }
        '''),
      );
    });

    test(
      'should work as an expression',
      () {
        final expr = SwitchExpression(
          (b) => b
            ..value = refer('otherValue')
            ..cases.addAll([
              Case((c) => c
                ..pattern = refer('Enum').property('someType')
                ..body = refer('someFunction').call([])),
              Case((c) => c
                ..pattern = refer('Enum').property('otherType')
                ..body = refer('otherFunction').call([]))
            ]),
        );

        final variable = declareFinal('variable').assign(expr);
        final parenthesized = expr.parenthesized;
        final operation = expr.operatorAdd(refer('otherResult'));

        expect(
            Block(
              (b) => b
                ..addExpression(variable)
                ..addExpression(parenthesized)
                ..addExpression(operation),
            ),
            equalsDart('''
final variable = switch (otherValue) {
  Enum.someType => someFunction(),
  Enum.otherType => otherFunction(),
};
(switch (otherValue) {
  Enum.someType => someFunction(),
  Enum.otherType => otherFunction(),
});
switch (otherValue) {
  Enum.someType => someFunction(),
  Enum.otherType => otherFunction(),
} + otherResult;
'''));
      },
    );
  });
}
