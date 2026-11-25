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

  group('IfElement', () {
    test('implements Spec without extending Expression', () {
      final element = IfElement(.expression(refer('ok')), literal(1));
      expect(element, isA<Spec>());
      expect(element, isNot(isA<Expression>()));
    });

    test('if element in list and set literals', () {
      expect(
        literalList([
          literal(1),
          IfElement(.expression(refer('includeTwo')), literal(2)),
        ]),
        equalsDart('[1, if (includeTwo) 2, ]'),
      );
      expect(
        literalSet([
          literal('a'),
          IfElement(.expression(refer('includeB')), literal('b')),
        ]),
        equalsDart("{'a', if (includeB) 'b', }"),
      );
    });

    test('if-else element', () {
      expect(
        literalList([
          IfElement(.expression(refer('flag')), literal(1), literal(2)),
        ]),
        equalsDart(r'''
          [if (flag) 1 else 2]
        '''),
      );
    });

    test('else-if chains with and without final else', () {
      expect(
        literalList([
          IfElement(
            .expression(refer('x').equalTo(literal(1))),
            literal('one'),
            IfElement(
              .expression(refer('x').equalTo(literal(2))),
              literal('two'),
            ),
          ),
        ]),
        equalsDart(r'''
          [if (x == 1) 'one' else if (x == 2) 'two']
        '''),
      );
      expect(
        literalSet([
          IfElement(
            .expression(refer('x').equalTo(literal(1))),
            literal('one'),
            IfElement(
              .expression(refer('x').equalTo(literal(2))),
              literal('two'),
              literal('other'),
            ),
          ),
        ]),
        equalsDart(r'''
          {if (x == 1) 'one' else if (x == 2) 'two' else 'other'}
        '''),
      );
    });

    test('if-case condition without and with guard', () {
      expect(
        literalList([
          IfElement(.ifCase(refer('value'), .declareFinal('v')), refer('v')),
        ]),
        equalsDart(r'''
          [if (value case final v) v]
        '''),
      );
      expect(
        literalSet([
          IfElement(
            .ifCase(
              refer('value'),
              .declareFinal('v'),
              guard: refer('v').greaterThan(literal(0)),
            ),
            refer('v'),
            literal(0),
          ),
        ]),
        equalsDart(r'''
          {if (value case final v when v > 0) v else 0}
        '''),
      );
    });

    test('rejects dangling else when then is direct unmatched IfElement', () {
      expect(
        () => IfElement(
          .expression(refer('c1')),
          IfElement(.expression(refer('c2')), literal('a')),
          literal('b'),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'then')
              .having(
                (e) => e.message,
                'message',
                contains('unmatched if element'),
              ),
        ),
      );
    });

    test(
      'rejects dangling else when ForElement wraps unmatched IfElement in then',
      () {
        expect(
          () => IfElement(
            .expression(refer('c1')),
            ForElement.forIn(
              declareFinal('v'),
              refer('xs'),
              IfElement(.expression(refer('c2')), literal('a')),
            ),
            literal('b'),
          ),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'then')
                .having(
                  (e) => e.message,
                  'message',
                  contains('unmatched if element'),
                ),
          ),
        );
        expect(
          () => IfElement(
            .expression(refer('c1')),
            ForElement(IfElement(.expression(refer('c2')), literal('a'))),
            literal('b'),
          ),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'then')),
        );
      },
    );

    test(
      'rejects dangling else when else-if chain in then lacks final else',
      () {
        expect(
          () => IfElement(
            .expression(refer('c0')),
            IfElement(
              .expression(refer('c1')),
              literal('a'),
              IfElement(.expression(refer('c2')), literal('b')),
            ),
            literal('c'),
          ),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'then')
                .having(
                  (e) => e.message,
                  'message',
                  contains('unmatched if element'),
                ),
          ),
        );
      },
    );

    test('allows outer else when inner IfElement has matched else', () {
      expect(
        literalList([
          IfElement(
            .expression(refer('c0')),
            IfElement(.expression(refer('c1')), refer('a'), refer('b')),
            refer('c'),
          ),
        ]),
        equalsDart(r'''
          [if (c0) if (c1) a else b else c]
        '''),
      );
      expect(
        literalList([
          IfElement(
            .expression(refer('c0')),
            ForElement.forIn(
              declareFinal('v'),
              refer('xs'),
              IfElement(.expression(refer('c1')), refer('a'), refer('b')),
            ),
            refer('c'),
          ),
        ]),
        equalsDart(r'''
          [if (c0) for (final v in xs) if (c1) a else b else c]
        '''),
      );
    });

    test('toString emits Dart representation', () {
      expect(
        IfElement(
          .expression(refer('flag')),
          literal(1),
          literal(2),
        ).toString(),
        'if (flag) 1 else 2',
      );
    });
  });

  group('ForElement', () {
    test('implements Spec without extending Expression', () {
      const Spec cLoop = ForElement(literalNull);
      const Spec forIn = ForElement.forIn(
        literalNull,
        literalNull,
        literalNull,
      );
      expect(cLoop, isA<ForElement>());
      expect(cLoop, isA<ForLoopElement>());
      expect(cLoop, isNot(isA<Expression>()));
      expect(forIn, isA<ForElement>());
      expect(forIn, isA<ForInElement>());
      expect(forIn, isNot(isA<Expression>()));
    });

    test('forIn with var, final, and async await for', () {
      expect(
        literalList([
          ForElement.forIn(
            declareVar('x'),
            refer('items'),
            refer('x').operatorAdd(literal(1)),
          ),
        ]),
        equalsDart(r'''
          [for (var x in items) x + 1]
        '''),
      );
      expect(
        literalSet([
          ForElement.forIn(declareFinal('item'), refer('items'), refer('item')),
        ]),
        equalsDart(r'''
          {for (final item in items) item}
        '''),
      );
      expect(
        literalList([
          ForElement.forIn(
            declareFinal('event'),
            refer('stream'),
            refer('event'),
            async: true,
          ),
        ]),
        equalsDart(r'''
          [await for (final event in stream) event]
        '''),
      );
    });

    test('C-style ForElement with all parts and omitted parts', () {
      expect(
        literalList([
          ForElement(
            refer('i'),
            initialize: declareVar('i').assign(literal(0)),
            condition: refer('i').lessThan(literal(5)),
            advance: refer('i').operatorUnaryPostfixIncrement(),
          ),
        ]),
        equalsDart(r'''
          [for (var i = 0; i < 5; i++) i]
        '''),
      );
      expect(
        literalSet([ForElement(refer('next').call([]))]),
        equalsDart(r'''
          {for (;;) next()}
        '''),
      );
      expect(
        literalList([
          ForElement(
            refer('i'),
            condition: refer('i').lessThan(literal(3)),
            advance: refer('i').operatorUnaryPostfixIncrement(),
          ),
        ]),
        equalsDart(r'''
          [for (; i < 3; i++) i]
        '''),
      );
    });

    test('nested control-flow elements in both directions', () {
      expect(
        literalList([
          ForElement.forIn(
            declareFinal('x'),
            refer('xs'),
            IfElement(
              .expression(refer('x').greaterThan(literal(0))),
              refer('x'),
            ),
          ),
        ]),
        equalsDart(r'''
          [for (final x in xs) if (x > 0) x]
        '''),
      );
      expect(
        literalSet([
          IfElement(
            .expression(refer('includeAll')),
            ForElement.forIn(declareFinal('x'), refer('xs'), refer('x')),
          ),
        ]),
        equalsDart(r'''
          {if (includeAll) for (final x in xs) x}
        '''),
      );
    });

    test('prefixes imported references with Allocator.simplePrefixing()', () {
      final check = refer('check', 'package:pkg_a/a.dart');
      final items = refer('items', 'package:pkg_b/b.dart');
      final transform = refer('transform', 'package:pkg_c/c.dart');
      final itemType = refer('Item', 'package:pkg_d/d.dart');
      expect(
        declareFinal('result')
            .assign(
              literalList([
                IfElement(
                  .ifCase(
                    refer('source', 'package:pkg_e/e.dart'),
                    .typed('matched', itemType),
                    guard: check.call([refer('matched')]),
                  ),
                  ForElement.forIn(
                    declareFinal('item', type: itemType),
                    items,
                    transform.call([refer('item')]),
                  ),
                  ForElement(
                    transform.call([refer('i')]),
                    initialize: declareVar('i').assign(literal(0)),
                    condition: check.call([refer('i')]),
                    advance: refer('i').operatorUnaryPostfixIncrement(),
                  ),
                ),
              ]),
            )
            .statement,
        equalsDart(r'''
          final result = [
            if (_i1.source case _i2.Item matched when _i3.check(matched))
              for (final _i2.Item item in _i4.items) _i5.transform(item)
            else
              for (var i = 0; _i3.check(i); i++) _i5.transform(i),
          ];
        ''', DartEmitter(allocator: Allocator.simplePrefixing())),
      );
    });

    test('toString emits Dart representation', () {
      expect(
        ForElement(
          refer('i'),
          initialize: declareVar('i').assign(literal(0)),
          condition: refer('i').lessThan(literal(3)),
          advance: refer('i').operatorUnaryPostfixIncrement(),
        ).toString(),
        'for (var i = 0; i < 3; i++) i',
      );
      expect(ForElement(refer('x')).toString(), 'for (;;) x');
      expect(
        ForElement.forIn(
          declareFinal('x'),
          refer('xs'),
          refer('x'),
          async: true,
        ).toString(),
        'await for (final x in xs) x',
      );
    });

    test('emits valid Dart compilation unit inside async Method', () {
      expect(
        Method(
          (b) => b
            ..name = 'collect'
            ..returns = refer('Future<List<int>>')
            ..modifier = MethodModifier.async
            ..body = literalList([
              IfElement(
                .expression(refer('c0')),
                IfElement(.expression(refer('c1')), literal(1), literal(2)),
                literal(3),
              ),
              ForElement.forIn(
                declareFinal('event'),
                refer('stream'),
                IfElement(
                  .ifCase(
                    refer('event'),
                    .declareFinal('v'),
                    guard: refer('v').greaterThan(literal(0)),
                  ),
                  refer('v'),
                ),
                async: true,
              ),
            ]).returned.statement,
        ),
        equalsDart(r'''
          Future<List<int>> collect() async {
            return [
              if (c0)
                if (c1) 1 else 2
              else
                3,
              await for (final event in stream)
                if (event case final v when v > 0) v,
            ];
          }
        '''),
      );
    });
  });

  group('collection elements integration', () {
    test(
      'emits json_serializable-style literalMapElements with entries, spreads, '
      'IfElement, and ForElement',
      () {
        expect(
          Method(
            (b) => b
              ..name = 'toJson'
              ..returns = refer('Map<String, Object?>')
              ..body = literalMapElements(
                [
                  refer('baseJson').spread,
                  refer('extraJson').nullSafeSpread,
                  MapLiteralEntry(
                    literalString('id'),
                    refer('instance').property('id'),
                  ),
                  MapLiteralEntry(
                    refer('dynamicKey'),
                    refer('instance').property('nickname'),
                    nullAwareKey: true,
                    nullAwareValue: true,
                  ),
                  IfElement(
                    .ifCase(
                      refer('instance').property('x'),
                      Pattern.declareFinal(r'$value').nullChecked,
                    ),
                    MapLiteralEntry(
                      literalString('x'),
                      refer('serialize').call([refer(r'$value')]),
                    ),
                  ),
                  ForElement.forIn(
                    declareFinal('entry'),
                    refer('entries'),
                    IfElement(
                      .expression(refer('entry').property('enabled')),
                      MapLiteralEntry(
                        refer('entry').property('key'),
                        refer('entry').property('value'),
                        nullAwareValue: true,
                      ),
                    ),
                  ),
                  ForElement(
                    MapLiteralEntry(
                      literalString(
                        'slot',
                      ).operatorAdd(refer('i').property('toString').call([])),
                      refer('slots').index(refer('i')),
                    ),
                    initialize: declareVar('i').assign(literal(0)),
                    condition: refer('i').lessThan(literal(2)),
                    advance: refer('i').operatorUnaryPostfixIncrement(),
                  ),
                ],
                refer('String'),
                TypeReference(
                  (b) => b
                    ..symbol = 'Object'
                    ..isNullable = true,
                ),
              ).returned.statement,
          ),
          equalsDart(r'''
            Map<String, Object?> toJson() {
              return <String, Object?>{
                ...baseJson,
                ...?extraJson,
                'id': instance.id,
                ?dynamicKey: ?instance.nickname,
                if (instance.x case final $value?) 'x': serialize($value),
                for (final entry in entries)
                  if (entry.enabled) entry.key: ?entry.value,
                for (var i = 0; i < 2; i++) 'slot' + i.toString(): slots[i],
              };
            }
          ''', DartEmitter(useNullSafetySyntax: true)),
        );
      },
    );

    test(
      'elides nested const across literalConstMapElements and IfElement',
      () {
        final constMap = literalConstMapElements([
          MapLiteralEntry(literalString('always'), literalConstList([1])),
          IfElement(
            .expression(refer('includeZero')),
            MapLiteralEntry(
              literalString('zero'),
              refer('Duration').constInstance([]),
            ),
            MapLiteralEntry(
              literalString('fallback'),
              refer('Duration').constInstance([], {'seconds': literal(1)}),
            ),
          ),
        ]);

        expect(
          constMap,
          equalsDart(
            "const {'always': [1], "
            "if (includeZero) 'zero': Duration() "
            "else 'fallback': Duration(seconds: 1), }",
          ),
        );
        expect(
          declareFinal('m').assign(constMap).statement,
          equalsDart(r'''
            final m = const {
              'always': [1],
              if (includeZero)
                'zero': Duration()
              else
                'fallback': Duration(seconds: 1),
            };
          '''),
        );
        expect(
          declareConst('kConfig').assign(constMap).statement,
          equalsDart(r'''
            const kConfig = {
              'always': [1],
              if (includeZero)
                'zero': Duration()
              else
                'fallback': Duration(seconds: 1),
            };
          '''),
        );
        expect(
          declareFinal('list').assign(literalConstList([constMap])).statement,
          equalsDart(r'''
            final list = const [
              {
                'always': [1],
                if (includeZero)
                  'zero': Duration()
                else
                  'fallback': Duration(seconds: 1),
              },
            ];
          '''),
        );
      },
    );

    test('emits NullAwareElement inside IfElement and ForElement in lists and '
        'sets', () {
      expect(
        declareFinal('list')
            .assign(
              literalList([
                IfElement(
                  .expression(refer('includeHead')),
                  refer('maybeHead').nullAwareElement,
                  refer('maybeFallback').nullAwareElement,
                ),
                ForElement.forIn(
                  declareFinal('item'),
                  refer('items'),
                  refer('item').property('maybeValue').nullAwareElement,
                ),
              ]),
            )
            .statement,
        equalsDart(r'''
            final list = [
              if (includeHead) ?maybeHead else ?maybeFallback,
              for (final item in items) ?item.maybeValue,
            ];
          '''),
      );
      expect(
        declareFinal('set')
            .assign(
              literalSet([
                ForElement(
                  IfElement(
                    .expression(refer('i').greaterThan(literal(0))),
                    refer('lookup').call([refer('i')]).nullAwareElement,
                  ),
                  initialize: declareVar('i').assign(literal(0)),
                  condition: refer('i').lessThan(literal(3)),
                  advance: refer('i').operatorUnaryPostfixIncrement(),
                ),
              ]),
            )
            .statement,
        equalsDart(r'''
            final set = {
              for (var i = 0; i < 3; i++)
                if (i > 0) ?lookup(i),
            };
          '''),
      );
    });

    test('prefixes references across nested control-flow and map elements with '
        'Allocator.simplePrefixing()', () {
      final emitter = DartEmitter(allocator: Allocator.simplePrefixing());
      final keyType = refer('Key', 'package:pkg_a/a.dart');
      final valType = refer('Val', 'package:pkg_b/b.dart');
      final defaults = refer('defaults', 'package:pkg_c/c.dart');
      final serialize = refer('serialize', 'package:pkg_d/d.dart');
      final source = refer('source', 'package:pkg_e/e.dart');

      expect(
        declareFinal('map')
            .assign(
              literalMapElements(
                [
                  defaults.nullSafeSpread,
                  IfElement(
                    .ifCase(source, .typed('v', valType)),
                    ForElement.forIn(
                      declareFinal('k', type: keyType),
                      refer('keys', 'package:pkg_a/a.dart'),
                      MapLiteralEntry(
                        refer('k'),
                        serialize.call([refer('v')]),
                        nullAwareKey: true,
                        nullAwareValue: true,
                      ),
                    ),
                  ),
                ],
                keyType,
                valType,
              ),
            )
            .statement,
        equalsDart(r'''
            final map = <_i1.Key, _i2.Val>{
              ...?_i3.defaults,
              if (_i4.source case _i2.Val v)
                for (final _i1.Key k in _i1.keys) ?k: ?_i5.serialize(v),
            };
          ''', emitter),
      );
    });

    test(
      'supports toString on collection literals containing control specs',
      () {
        expect(
          literalList([
            IfElement(.expression(refer('flag')), literal(1), literal(2)),
          ]).toString(),
          '[if (flag) 1 else 2]',
        );
        expect(
          literalSet([
            ForElement.forIn(declareFinal('x'), refer('xs'), refer('x')),
          ]).toString(),
          '{for (final x in xs) x}',
        );
        expect(
          literalMapElements([
            IfElement(
              .expression(refer('flag')),
              MapLiteralEntry(
                literalString('a'),
                refer('x'),
                nullAwareValue: true,
              ),
            ),
          ]).toString(),
          "{if (flag) 'a': ?x}",
        );
      },
    );
  });
}
