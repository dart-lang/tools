// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  useDartfmt();

  group('Conditional', () {
    test('if statement', () {
      expect(
        Conditional(
          (b) => b
            ..branches.add(
              .new(
                (b) => b
                  ..condition = .expression(refer('x').equalTo(literal(1)))
                  ..body = refer('print').call([literal('one')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          if (x == 1) {
            print('one');
          }
        '''),
      );
    });

    test('if-else statement', () {
      expect(
        Conditional(
          (b) => b
            ..branches.add(
              .new(
                (b) => b
                  ..condition = .expression(refer('x').equalTo(literal(1)))
                  ..body = refer('print').call([literal('one')]).statement,
              ),
            )
            ..orElse = refer('print').call([literal('other')]).statement,
        ),
        equalsDart(r'''
          if (x == 1) {
            print('one');
          } else {
            print('other');
          }
        '''),
      );
    });

    test('if-else-if-else statement', () {
      expect(
        Conditional(
          (b) => b
            ..branches.addAll([
              .new(
                (b) => b
                  ..condition = .expression(refer('x').equalTo(literal(1)))
                  ..body = refer('print').call([literal('one')]).statement,
              ),
              .new(
                (b) => b
                  ..condition = .expression(refer('x').equalTo(literal(2)))
                  ..body = refer('print').call([literal('two')]).statement,
              ),
            ])
            ..orElse = refer('print').call([literal('other')]).statement,
        ),
        equalsDart(r'''
          if (x == 1) {
            print('one');
          } else if (x == 2) {
            print('two');
          } else {
            print('other');
          }
        '''),
      );
    });

    test('if-case condition', () {
      expect(
        Conditional(
          (b) => b
            ..branches.add(
              .new(
                (b) => b
                  ..condition = .ifCase(refer('x'), .refer('Pattern'))
                  ..body = refer('print').call([literal('matched')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          if (x case Pattern) {
            print('matched');
          }
        '''),
      );
    });

    test('if-case condition with guard', () {
      expect(
        Conditional(
          (b) => b
            ..branches.add(
              .new(
                (b) => b
                  ..condition = .ifCase(
                    refer('x'),
                    .refer('Pattern'),
                    guard: refer('y').greaterThan(literal(0)),
                  )
                  ..body = refer('print').call([literal('matched')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          if (x case Pattern when y > 0) {
            print('matched');
          }
        '''),
      );
    });

    test('throws if no branches specified', () {
      expect(() => Conditional((b) => b), throwsArgumentError);
    });
  });

  group('ForLoop', () {
    test('traditional for loop', () {
      expect(
        ForLoop(
          (b) => b
            ..initialize = declareVar('i').assign(literal(0))
            ..condition = refer('i').lessThan(literal(10))
            ..advance = refer('i').operatorUnaryPostfixIncrement()
            ..body = refer('print').call([refer('i')]).statement,
        ),
        equalsDart(r'''
          for (var i = 0; i < 10; i++) {
            print(i);
          }
        '''),
      );
    });

    test('for loop with omitted parts', () {
      expect(
        ForLoop(
          (b) => b..body = refer('print').call([literal('infinite')]).statement,
        ),
        equalsDart(r'''
          for (;;) {
            print('infinite');
          }
        '''),
      );
    });

    test('for loop with label', () {
      expect(
        ForLoop(
          (b) => b
            ..initialize = declareVar('i').assign(literal(0))
            ..condition = refer('i').lessThan(literal(10))
            ..advance = refer('i').operatorUnaryPostfixIncrement()
            ..body = refer('print').call([refer('i')]).statement
            ..label = 'outer',
        ),
        equalsDart(r'''
          outer:
          for (var i = 0; i < 10; i++) {
            print(i);
          }
        '''),
      );
    });
  });

  group('ForInLoop', () {
    test('synchronous for-in loop', () {
      expect(
        ForInLoop(
          (b) => b
            ..variable = declareFinal('item')
            ..object = refer('items')
            ..body = refer('print').call([refer('item')]).statement,
        ),
        equalsDart(r'''
          for (final item in items) {
            print(item);
          }
        '''),
      );
    });

    test('asynchronous await for loop', () {
      expect(
        ForInLoop(
          (b) => b
            ..variable = declareFinal('event')
            ..object = refer('stream')
            ..body = refer('print').call([refer('event')]).statement
            ..async = true,
        ),
        equalsDart(r'''
          await for (final event in stream) {
            print(event);
          }
        '''),
      );
    });

    test('for-in loop with label', () {
      expect(
        ForInLoop(
          (b) => b
            ..variable = declareFinal('item')
            ..object = refer('items')
            ..body = refer('print').call([refer('item')]).statement
            ..label = 'itemLoop',
        ),
        equalsDart(r'''
          itemLoop:
          for (final item in items) {
            print(item);
          }
        '''),
      );
    });
  });

  group('WhileLoop', () {
    test('while loop', () {
      expect(
        WhileLoop(
          (b) => b
            ..condition = refer('running')
            ..body = refer('doWork').call([]).statement,
        ),
        equalsDart(r'''
          while (running) {
            doWork();
          }
        '''),
      );
    });

    test('do-while loop', () {
      expect(
        WhileLoop(
          (b) => b
            ..condition = refer('running')
            ..body = refer('doWork').call([]).statement
            ..doWhile = true,
        ),
        equalsDart(r'''
          do {
            doWork();
          } while (running);
        '''),
      );
    });

    test('while loop with label', () {
      expect(
        WhileLoop(
          (b) => b
            ..condition = refer('running')
            ..body = refer('doWork').call([]).statement
            ..label = 'loop',
        ),
        equalsDart(r'''
          loop:
          while (running) {
            doWork();
          }
        '''),
      );
    });
  });

  group('Try', () {
    test('try-catch', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..catches.add(
              .new(
                (b) => b
                  ..exception = 'e'
                  ..body = refer('print').call([refer('e')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          try {
            risky();
          } catch (e) {
            print(e);
          }
        '''),
      );
    });

    test('try-on without exception', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..catches.add(
              .new(
                (b) => b
                  ..on = refer('FormatException')
                  ..body = refer('print').call([literal('error')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          try {
            risky();
          } on FormatException {
            print('error');
          }
        '''),
      );
    });

    test('try-on-catch with stack trace', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..catches.add(
              .new(
                (b) => b
                  ..on = refer('FormatException')
                  ..exception = 'e'
                  ..stackTrace = 's'
                  ..body = refer('print').call([refer('s')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          try {
            risky();
          } on FormatException catch (e, s) {
            print(s);
          }
        '''),
      );
    });

    test('try-catch with stack trace only', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..catches.add(
              .new(
                (b) => b
                  ..stackTrace = 's'
                  ..body = refer('print').call([refer('s')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          try {
            risky();
          } catch (_, s) {
            print(s);
          }
        '''),
      );
    });

    test('try-finally without catch', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..finallyBlock = refer('cleanup').call([]).statement,
        ),
        equalsDart(r'''
          try {
            risky();
          } finally {
            cleanup();
          }
        '''),
      );
    });

    test('try-catch-finally', () {
      expect(
        Try(
          (b) => b
            ..body = refer('risky').call([]).statement
            ..catches.add(
              .new(
                (b) => b
                  ..exception = 'e'
                  ..body = refer('print').call([refer('e')]).statement,
              ),
            )
            ..finallyBlock = refer('cleanup').call([]).statement,
        ),
        equalsDart(r'''
          try {
            risky();
          } catch (e) {
            print(e);
          } finally {
            cleanup();
          }
        '''),
      );
    });

    test('throws if neither catch nor finally specified', () {
      expect(() => Try((b) => b), throwsArgumentError);
    });
  });

  group('SwitchStatement', () {
    test('basic switch statement', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('value')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .literal(1)
                  ..body = refer('print').call([literal('one')]).statement,
              ),
            )
            ..defaultCase = refer('print').call([literal('other')]).statement,
        ),
        equalsDart(r'''
          switch (value) {
            case 1:
              print('one');
            default:
              print('other');
          }
        '''),
      );
    });

    test('switch statement with guard and fall-through', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('value')
            ..cases.addAll([
              .new((b) => b..pattern = .literal(1)),
              .new(
                (b) => b
                  ..pattern = .literal(2)
                  ..guard = refer('flag')
                  ..body = refer('print').call([literal('small')]).statement,
              ),
            ]),
        ),
        equalsDart(r'''
          switch (value) {
            case 1:
            case 2 when flag:
              print('small');
          }
        '''),
      );
    });

    test('switch statement with case label and statement label', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('value')
            ..label = 'mySwitch'
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .literal(1)
                  ..label = 'caseOne'
                  ..body = refer('print').call([literal('one')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          mySwitch:
          switch (value) {
            caseOne:
            case 1:
              print('one');
          }
        '''),
      );
    });
  });

  group('SwitchExpression', () {
    test('basic switch expression', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('value')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .literal(1)
                  ..body = literal('one'),
              ),
              .new(
                (b) => b
                  ..pattern = .literal(2)
                  ..body = literal('two'),
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literal('other'),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (value) {
            1 => 'one',
            2 => 'two',
            _ => 'other',
          }
        '''),
      );
    });

    test('switch expression with guard', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('value')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .declareVar('x')
                  ..guard = refer('x').greaterThan(literal(0))
                  ..body = literal('positive'),
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literal('non-positive'),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (value) {
            var x when x > 0 => 'positive',
            _ => 'non-positive',
          }
        '''),
      );
    });

    test('switch expression inside assignment', () {
      expect(
        declareFinal('result')
            .assign(
              SwitchExpression(
                (b) => b
                  ..value = refer('status')
                  ..cases.addAll([
                    .new(
                      (b) => b
                        ..pattern = .literal(200)
                        ..body = literal('OK'),
                    ),
                    .new(
                      (b) => b
                        ..pattern = .wildcard
                        ..body = literal('Error'),
                    ),
                  ]),
              ),
            )
            .statement,
        equalsDart(r'''
          final result = switch (status) {
            200 => 'OK',
            _ => 'Error',
          };
        '''),
      );
    });
  });
}
