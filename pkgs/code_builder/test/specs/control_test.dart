// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

extension on Catch {
  TryCatch get blank => TryCatch((builder) {
    builder.addCatch(this);
  });
}

void main() {
  useDartfmt();

  group('for loop', () {
    test('should emit a full for loop with body', () {
      final loop = ForLoop((b) {
        b
          ..initialize = declareVar('i', type: refer('int')).assign(literal(0))
          ..condition = refer('i').lessThan(literal(5))
          ..advance = refer('i').operatorUnaryPostfixIncrement()
          ..body = refer('print').call([refer('i')]).statement;
      });

      expect(loop, equalsDart('for (int i = 0; i < 5; i++) {\n  print(i);\n}'));
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
          ..body = refer('process').call([]).statement;
      });

      expect(loop, equalsDart('do {\n  process();\n} while (keepGoing);'));
    });

    test('should emit a labeled do-while loop', () {
      final loop = WhileLoop((b) {
        b
          ..doWhile = true
          ..label = 'mainLoop'
          ..condition = refer('keepGoing')
          ..body = refer('process').call([]).statement;
      });

      expect(
        loop,
        equalsDart('mainLoop: do {\n  process();\n} while (keepGoing);'),
      );
    });
  });

  group('conditional', () {
    test('should emit a single if block', () {
      final tree = Conditional(
        (tree) => tree.add(
          Branch(
            (b) =>
                b
                  ..condition = refer('x').equalTo(literal(1))
                  ..addExpression(refer('print').call([literal('one')])),
          ),
        ),
      );

      expect(tree, equalsDart('if (x == 1) {\n  print(\'one\');\n}'));
    });

    test('should emit a single if-case block', () {
      final tree = Conditional(
        (tree) => tree.add(
          Branch(
            (b) =>
                b
                  ..ifCase(object: refer('x'), pattern: refer('y'))
                  ..body = ControlFlow.returnVoid.statement,
          ),
        ),
      );

      expect(tree, equalsDart('if (x case y) {\n  return;\n}'));
    });

    test('should emit a single if-case block with guard', () {
      final tree = Conditional(
        (tree) => tree.add(
          Branch(
            (b) =>
                b
                  ..ifCase(
                    object: refer('x'),
                    pattern: refer('y'),
                    guard: refer('z'),
                  )
                  ..body = ControlFlow.returnVoid.statement,
          ),
        ),
      );

      expect(tree, equalsDart('if (x case y when z) {\n  return;\n}'));
    });

    test('should emit if-else if-else chain', () {
      final tree = Conditional((tree) {
        tree
          ..add(
            Branch.from(
              refer('x').equalTo(literal(1)),
              refer('print').call([literal('one')]).statement,
            ),
          )
          ..add(
            Branch(
              (branch) =>
                  branch
                    ..condition = refer('x').equalTo(literal(2))
                    ..addExpression(refer('print').call([literal('two')]))
                    ..addCode(const Code('// do something else\n')),
            ),
          )
          ..addElse(refer('print').call([literal('other')]).statement);
      });

      expect(
        tree,
        equalsDart('''
if (x == 1) {
  print('one');
} else if (x == 2) {
  print('two');
  // do something else
} else {
  print('other');
}'''),
      );
    });

    test('should support elseIf', () {
      final tree = Branch((b) {
        b
          ..condition = refer('loggedIn')
          ..body = refer('getDashboard').call([]).awaited.statement
          ..addExpression(refer('showDashboard').call([]))
          ..addCode(const Code('// comment\n'));
      }).asConditional.elseIf(
        Branch((b) {
          b
            ..condition = refer('isGuest')
            ..body = refer('showGuest').call([]).statement;
        }),
      );

      expect(
        tree,
        equalsDart('''
if (loggedIn) {
  await getDashboard();
  showDashboard();
  // comment
} else if (isGuest) {
  showGuest();
}'''),
      );
    });

    test('should support orElse', () {
      final tree = Branch((b) {
        b
          ..condition = refer('ready')
          ..body = refer('start').call([]).statement;
      }).asConditional.orElse(
        refer('log').call([literal('not ready')]).statement,
      );

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

    test('should throw an argument error', () {
      final tree = Conditional.from([Branch((branch) {})]);

      expect(() => tree.accept(DartEmitter()), throwsArgumentError);
    });
  });

  group('catch block', () {
    test('should emit catch with default exception name', () {
      final catchBlock = Catch((b) => b..body = literal(1).statement);
      expect(catchBlock.blank, equalsDart('try {} catch (_) {\n  1;\n}'));
    });

    test('should emit catch with custom exception name', () {
      final catchBlock = Catch(
        (b) =>
            b
              ..exception = 'err'
              ..body = literal(2).statement,
      );
      expect(catchBlock.blank, equalsDart('try {} catch (err) {\n  2;\n}'));
    });

    test('should emit catch with exception and stacktrace', () {
      final catchBlock = Catch(
        (b) =>
            b
              ..exception = 'e'
              ..stacktrace = 's'
              ..body = refer('log').call([refer('s')]).statement,
      );
      expect(
        catchBlock.blank,
        equalsDart('try {} catch (e, s) {\n  log(s);\n}'),
      );
    });

    test('should emit an on block', () {
      final catchBlock = Catch(
        (b) =>
            b
              ..type = refer('FormatException')
              ..body = refer('print').call([refer('e')]).statement,
      );
      expect(
        catchBlock.blank,
        equalsDart('try {} on FormatException {\n  print(e);\n}'),
      );
    });

    test('should emit on-type catch block', () {
      final catchBlock = Catch(
        (b) =>
            b
              ..type = refer('FormatException')
              ..stacktrace = 's'
              ..body = refer('print').call([refer('e')]).statement,
      );
      expect(
        catchBlock.blank,
        equalsDart('try {} on FormatException catch (_, s) {\n  print(e);\n}'),
      );
    });
  });

  group('try-catch', () {
    test('should throw if no catch handlers are defined', () {
      expect(
        () => TryCatch((b) => b.body = literal(1).statement),
        throwsArgumentError,
      );
    });

    test('should emit try/catch block', () {
      final block = TryCatch((b) {
        b
          ..body = refer('mightFail').call([]).statement
          ..addCatch(
            Catch((cb) => cb.body = refer('handleError').call([]).statement),
          );
      });

      expect(
        block,
        equalsDart('''
try {
  mightFail();
} catch (_) {
  handleError();
}'''),
      );
    });

    test('should emit an on block', () {
      final block = TryCatch(
        (b) =>
            b
              ..body = refer('mightFail').call([]).statement
              ..addCatch(
                Catch(
                  (c) =>
                      c
                        ..type = refer('HttpException')
                        ..body = ControlFlow.rethrowVoid.statement,
                ),
              ),
      );

      expect(
        block,
        equalsDart('''
try {
  mightFail();
} on HttpException {
  rethrow;
}
'''),
      );
    });

    test('should emit try/on-type/catch with finally', () {
      final block = TryCatch((b) {
        b
          ..body = refer('mightFail').call([]).statement
          ..addCatch(
            Catch(
              (cb) =>
                  cb
                    ..type = refer('HttpException')
                    ..exception = 'e'
                    ..stacktrace = 's'
                    ..body = refer('print').call([refer('s')]).statement,
            ),
          )
          ..addFinally(refer('cleanup').call([]).statement);
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
          ..body = refer('foo').call([]).statement
          ..addCatch(
            Catch(
              (cb) =>
                  cb
                    ..type = refer('FormatException')
                    ..exception = 'e1'
                    ..body = refer('handleFormat').call([]).statement,
            ),
          )
          ..addCatch(
            Catch(
              (cb) =>
                  cb
                    ..type = refer('SocketException')
                    ..exception = 'e2'
                    ..body = refer('handleSocket').call([]).statement,
            ),
          )
          ..addCatch(
            Catch((cb) => cb.body = ControlFlow.rethrowVoid.statement),
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
} catch (_) {
  rethrow;
}'''),
      );
    });
  });

  group('try-catch builder', () {
    test('addCatch should append to handlers', () {
      final result =
          (TryCatchBuilder()
                ..body = literal(0).statement
                ..addCatch(Catch((cb) => cb.body = literal(1).statement)))
              .build();
      expect(result.handlers, hasLength(1));
      expect(
        result,
        equalsDart('''
try {
  0;
} catch (_) {
  1;
}
'''),
      );
    });

    test('addFinally should update handleAll', () {
      final builder =
          TryCatchBuilder()
            ..body = literal(0).statement
            ..addCatch(Catch((cb) => cb.body = literal(1).statement))
            ..addFinally(refer('done').statement);

      final result = builder.build();
      expect(result.handleAll, isNotNull);
      expect(
        result,
        equalsDart('''
try {
  0;
} catch (_) {
  1;
} finally {
  done;
}
'''),
      );
    });
  });

  group('case', () {
    test('isDefault should be the same as Case.any', () {
      final first = Case(
        (builder) =>
            builder
              ..isDefault = true
              ..body = refer('foo'),
      );

      final second = Case.any(refer('foo'));

      expect(first, equals(second));
    });

    test('should require pattern when not default', () {
      final first =
          CaseBuilder()
            ..pattern = null
            ..isDefault = true
            ..body = refer('foo');

      final second =
          CaseBuilder()
            ..pattern = null
            ..isDefault = false
            ..body = refer('foo');

      final third = CaseBuilder()..body = refer('foo');

      expect(first.build(), isA<Case>());
      expect(second.build, throwsArgumentError);
      expect(third.build, throwsArgumentError);
    });
  });

  group('switch statement', () {
    test('should emit basic case with single statement body', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('x');
        b.cases.add(
          Case((cb) {
            cb
              ..pattern = literal(1)
              ..body = refer('print').call([literal('one')]).statement;
          }),
        );
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

    test('should emit basic case using Case.from', () {
      final stmt = SwitchStatement.from(refer('x'), [
        Case.from(literal(1), refer('print').call([literal('one')]).statement),
      ]);

      expect(
        stmt,
        equalsDart('''
switch (x) {
  case 1:
    print('one');
}'''),
      );
    });

    test('should emit multiple cases using Case.from', () {
      final stmt = SwitchStatement.from(refer('x'), [
        Case.from(literal(1), refer('print').call([literal('one')]).statement),
        Case.from(literal(2), refer('print').call([literal('two')]).statement),
        Case.from(
          literal(3),
          refer('print').call([literal('three')]).statement,
        ),
      ]);

      expect(
        stmt,
        equalsDart('''
switch (x) {
  case 1:
    print('one');
  case 2:
    print('two');
  case 3:
    print('three');
}'''),
      );
    });

    test('should emit multiline case', () {
      final stmt = SwitchStatement((b) {
        b.value = refer('x');
        b.cases.add(
          Case((cb) {
            cb
              ..pattern = literal(1)
              ..body = Block.of([
                refer('print').call([literal('one')]).statement,
                refer('print').call([literal('two')]).statement,
                ControlFlow.breakVoid.statement,
              ]);
          }),
        );
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
          Case(
            (cb) =>
                cb
                  ..pattern = literal(1)
                  ..body = refer('print').call([literal('first')]).statement,
          ),
          Case(
            (cb) =>
                cb
                  ..pattern = literal(2)
                  ..body = refer('print').call([literal('second')]).statement,
          ),
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
          Case(
            (cb) =>
                cb
                  ..pattern = literal(0)
                  ..body = null,
          ),
          Case(
            (cb) =>
                cb
                  ..pattern = literal(1)
                  ..body = refer('handleOne').call([]).statement,
          ),
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
        b.cases.add(
          Case(
            (cb) =>
                cb
                  ..pattern = literal(5)
                  ..guard = refer('value').greaterThan(literal(2))
                  ..body = refer('print').call([literal('guarded')]).statement,
          ),
        );
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
        b.cases.add(
          Case(
            (cb) =>
                cb
                  ..label = 'start'
                  ..pattern = literal(0)
                  ..body = refer('begin').call([]).statement,
          ),
        );
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
          Case(
            (cb) =>
                cb
                  ..label = 'init'
                  ..pattern = literal('A')
                  ..body = null,
          ),
          Case(
            (cb) =>
                cb
                  ..pattern = literal('B')
                  ..body = refer('continueProcess').call([]).statement,
          ),
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
        b.cases.add(
          Case.any(refer('log').call([literal('default')]).statement),
        );
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
        b.cases.add(
          Case.any(
            refer('log').call([literal('default')]).statement,
            label: 'label',
          ),
        );
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
        b.cases.add(
          Case(
            (cb) =>
                cb
                  ..pattern = Expression.wildcard
                  ..body = refer('log').call([literal('wildcard')]).statement,
          ),
        );
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

    test(
      'should emit full mixed case block with guard, label, and default',
      () {
        final stmt = SwitchStatement((b) {
          b.value = refer('x');
          b.cases.addAll([
            Case((cb) => cb..pattern = literal(-1)),
            Case(
              (cb) =>
                  cb
                    ..pattern = literal(0)
                    ..body = ControlFlow.continueLabel('other').statement,
            ),
            Case(
              (cb) =>
                  cb
                    ..pattern = literal(1)
                    ..guard = refer('x').equalTo(literal(1))
                    ..body = refer('handleOne').call([]).statement,
            ),
            Case(
              (cb) =>
                  cb
                    ..pattern = literal(2)
                    ..label = 'other'
                    ..body = Block.of([
                      refer('printWarning').call([]).statement,
                      refer('handleNotOne').call([]).statement,
                    ]),
            ),
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
      },
    );
  });

  group('switch expression', () {
    final matchValue = refer('value');

    test('should generate a single-case switch expression', () {
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = matchValue
              ..cases.add(
                Case(
                  (b) =>
                      b
                        ..pattern = refer('1')
                        ..body = refer("'one'"),
                ),
              ),
      );

      expect(
        expr,
        equalsDart('''
          switch (value) {
            1 => 'one',
          }
        '''),
      );
    });

    test('should generate a single-case expression using Case.from', () {
      final expr = declareFinal('text').assign(
        SwitchExpression.from(matchValue, [
          Case.from(literal(1), literal('one')),
        ]),
      );

      expect(
        expr,
        equalsDart('''
          final text = switch (value) {
            1 => 'one',
          }
        '''),
      );
    });

    test('should generate a multi-case expression using Case.from', () {
      final expr = declareFinal('text').assign(
        SwitchExpression.from(matchValue, [
          Case.from(literal(1), literal('one')),
          Case.from(literal(2), literal('two')),
          Case.from(literal(3), literal('three')),
        ]),
      );

      expect(
        expr,
        equalsDart('''
          final text = switch (value) {
            1 => 'one',
            2 => 'two',
            3 => 'three',
          }
        '''),
      );
    });

    test('should support guard expressions in cases', () {
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = matchValue
              ..cases.add(
                Case(
                  (b) =>
                      b
                        ..pattern = refer('x')
                        ..guard = refer('x > 5')
                        ..body = refer("'greater than 5'"),
                ),
              ),
      );

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
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = matchValue
              ..cases.add(
                Case(
                  (b) =>
                      b
                        ..pattern = refer('2')
                        ..label = 'ignoredLabel'
                        ..body = refer("'two'"),
                ),
              ),
      );

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
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = matchValue
              ..cases.add(Case.any(refer("'default'"))),
      );

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
        () => SwitchExpression(
          (b) =>
              b
                ..value = matchValue
                ..cases.add(Case((b) => b..pattern = refer('1'))),
        ).accept(DartEmitter()),
        throwsArgumentError,
      );
    });

    test('should generate multiple cases with mixed guards and default', () {
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = matchValue
              ..cases.addAll([
                Case(
                  (b) =>
                      b
                        ..pattern = refer('1')
                        ..body = refer("'one'"),
                ),
                Case(
                  (b) =>
                      b
                        ..pattern = refer('2')
                        ..guard = refer('checkTwo()')
                        ..body = refer("'two'"),
                ),
                Case.any(refer("'fallback'")),
              ]),
      );

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

    test('should work as an expression', () {
      final expr = SwitchExpression(
        (b) =>
            b
              ..value = refer('otherValue')
              ..cases.addAll([
                Case(
                  (c) =>
                      c
                        ..pattern = refer('Enum').property('someType')
                        ..body = refer('someFunction').call([]),
                ),
                Case(
                  (c) =>
                      c
                        ..pattern = refer('Enum').property('otherType')
                        ..body = refer('otherFunction').call([]),
                ),
              ]),
      );

      final variable = declareFinal('variable').assign(expr);
      final parenthesized = expr.parenthesized;
      final operation = expr.operatorAdd(refer('otherResult'));

      expect(
        Block(
          (b) =>
              b
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
'''),
      );
    });
  });

  test('control flow blocks should be nestable', () {
    final list = ['foo', 'bar', 'baz', 100];

    final expr = TryCatch((builder) {
      builder.body = const Code('// Parse the list\n');

      for (final (index, item) in list.indexed) {
        builder
          ..addCode(Code('// Handle item ${index + 1}'))
          ..addCode(
            refer('list')
                .property('elementAt')
                .call([literal(index)])
                .notEqualTo(literal(item))
                .ifThen(literal('Invalid element $index').thrown.statement),
          )
          ..addCode(const Code('\n'));
      }

      builder
        ..addExpression(refer('doSomething').call([refer('list')]))
        ..addCatch(
          Catch(
            (builder) =>
                builder
                  ..exception = 'error'
                  ..body = SwitchStatement(
                    (s) =>
                        s
                          ..value = refer('error')
                          ..add(
                            Case.from(
                              declareFinal(
                                'error',
                                type: refer('DoSomethingError'),
                              ),
                              refer(
                                'fixSomething',
                              ).call([refer('error')]).statement,
                            ),
                          )
                          ..add(
                            Case(
                              (builder) =>
                                  builder
                                    ..pattern = declareFinal(
                                      '_',
                                      type: refer('String'),
                                    )
                                    ..body = refer('null').returned.statement
                                    ..guard = refer(
                                      'list',
                                    ).property('isNotEmpty'),
                            ),
                          )
                          ..add(Case.any(ControlFlow.rethrowVoid.statement)),
                  ),
          ),
        );
    });

    final func = Method((b) {
      b
        ..name = 'handleList'
        ..annotations.add(refer('internal'))
        ..requiredParameters.add(
          Parameter(
            (p) =>
                p
                  ..name = 'list'
                  ..type = refer('List'),
          ),
        )
        ..body = expr;
    });

    expect(
      func,
      equalsDart('''
@internal
handleList(List list) {
  try {
    // Parse the list

    // Handle item 1
    if (list.elementAt(0) != 'foo') {
      throw 'Invalid element 0';
    }

    // Handle item 2
    if (list.elementAt(1) != 'bar') {
      throw 'Invalid element 1';
    }

    // Handle item 3
    if (list.elementAt(2) != 'baz') {
      throw 'Invalid element 2';
    }

    // Handle item 4
    if (list.elementAt(3) != 100) {
      throw 'Invalid element 3';
    }

    doSomething(list);
  } catch (error) {
    switch (error) {
      case final DoSomethingError error:
        fixSomething(error);
      case final String _ when list.isNotEmpty:
        return null;
      default:
        rethrow;
    }
  }
}
'''),
    );
  });
}
