// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  useDartfmt();

  group('Logical Patterns', () {
    test('logical-or pattern', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('color')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .refer(
                    'Color.red',
                  ).or(.refer('Color.yellow')).or(.refer('Color.blue'))
                  ..body = literalTrue,
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literalFalse,
              ),
            ]),
        ),
        equalsDart(r'''
          switch (color) {
            Color.red || Color.yellow || Color.blue => true,
            _ => false,
          }
        '''),
      );
    });

    test('logical-and pattern', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('x')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .greaterThan(
                    literal(0),
                  ).and(.lessThan(literal(10)))
                  ..body = literal('single-digit'),
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literal('other'),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (x) {
            > 0 && < 10 => 'single-digit',
            _ => 'other',
          }
        '''),
      );
    });
  });

  group('Relational Patterns', () {
    test('relational operators', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('val')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .equalTo(literal(0))
                  ..body = literal('zero'),
              ),
              .new(
                (b) => b
                  ..pattern = .notEqualTo(literal(1))
                  ..body = literal('not-one'),
              ),
              .new(
                (b) => b
                  ..pattern = .greaterThan(literal(10))
                  ..body = literal('gt-10'),
              ),
              .new(
                (b) => b
                  ..pattern = .greaterOrEqualTo(literal(5))
                  ..body = literal('gte-5'),
              ),
              .new(
                (b) => b
                  ..pattern = .lessThan(literal(0))
                  ..body = literal('negative'),
              ),
              .new(
                (b) => b
                  ..pattern = .lessOrEqualTo(literal(-5))
                  ..body = literal('lte-neg-5'),
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literal('other'),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (val) {
            == 0 => 'zero',
            != 1 => 'not-one',
            > 10 => 'gt-10',
            >= 5 => 'gte-5',
            < 0 => 'negative',
            <= -5 => 'lte-neg-5',
            _ => 'other',
          }
        '''),
      );
    });
  });

  group('Unary Patterns', () {
    test('null-check pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('maybeString')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .var_('s').nullChecked
                  ..body = refer('print').call([refer('s')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (maybeString) {
            case var s?:
              print(s);
          }
        '''),
      );
    });

    test('null-assert pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('row')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .list([
                    .literal('user'),
                    .var_('name').nullAsserted,
                  ])
                  ..body = refer('print').call([refer('name')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (row) {
            case ['user', var name!]:
              print(name);
          }
        '''),
      );
    });

    test('cast pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('record')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .record(
                    positional: [
                      .var_('i').asA(refer('int')),
                      .var_('s').asA(refer('String')),
                    ],
                  )
                  ..body = refer('print').call([refer('i')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (record) {
            case (var i as int, var s as String):
              print(i);
          }
        '''),
      );
    });

    test('parenthesized pattern', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('x')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .greaterThan(literal(0))
                      .and(.lessThan(literal(10)))
                      .parenthesized
                      .or(.equalTo(literal(100)))
                  ..body = literalTrue,
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literalFalse,
              ),
            ]),
        ),
        equalsDart(r'''
          switch (x) {
            (> 0 && < 10) || == 100 => true,
            _ => false,
          }
        '''),
      );
    });
  });

  group('Constant & Variable Patterns', () {
    test('constant pattern with const (...) wrapper', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('x')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .constant(
                    refer('a').operatorAdd(refer('b')),
                    isConst: true,
                  )
                  ..body = refer('print').call([literal('matched')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (x) {
            case const (a + b):
              print('matched');
          }
        '''),
      );
    });

    test('variable patterns: var, final, typed, final typed', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('shape')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .var_('a')
                  ..body = refer('print').call([refer('a')]).statement,
              ),
              .new(
                (b) => b
                  ..pattern = .final_('b')
                  ..body = refer('print').call([refer('b')]).statement,
              ),
              .new(
                (b) => b
                  ..pattern = .typed('c', refer('int'))
                  ..body = refer('print').call([refer('c')]).statement,
              ),
              .new(
                (b) => b
                  ..pattern = .final_('d', type: refer('String'))
                  ..body = refer('print').call([refer('d')]).statement,
              ),
            ]),
        ),
        equalsDart(r'''
          switch (shape) {
            case var a:
              print(a);
            case final b:
              print(b);
            case int c:
              print(c);
            case final String d:
              print(d);
          }
        '''),
      );
    });

    test('wildcard pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('record')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .record(positional: [.wildcard, .wildcard])
                  ..body = refer('print').call([literal('matched')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (record) {
            case (_, _):
              print('matched');
          }
        '''),
      );
    });
  });

  group('Destructuring Patterns', () {
    test('list pattern with rest element', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('list')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .list(
                    [.var_('a'), .var_('b'), .var_('c')],
                    rest: .var_('rest'),
                    restIndex: 2,
                  )
                  ..body = refer('print').call([refer('rest')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (list) {
            case [var a, var b, ...var rest, var c]:
              print(rest);
          }
        '''),
      );
    });

    test('list pattern validates restIndex', () {
      expect(
        () => Pattern.list([.var_('a')], rest: .wildcard, restIndex: 2),
        throwsRangeError,
      );
      expect(
        () => Pattern.list([.var_('a')], rest: .wildcard, restIndex: -1),
        throwsRangeError,
      );
    });

    test('typed list pattern with anonymous rest element', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('list')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .list(
                    [.var_('first')],
                    type: refer('int'),
                    rest: .wildcard,
                    restIndex: 1,
                  )
                  ..body = refer('print').call([refer('first')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (list) {
            case <int>[var first, ..._]:
              print(first);
          }
        '''),
      );
    });

    test('map pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('map')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .map({
                    literal('name'): .var_('name'),
                    literal('age'): .typed('age', refer('int')),
                  })
                  ..body = refer('print').call([refer('name')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (map) {
            case {'name': var name, 'age': int age}:
              print(name);
          }
        '''),
      );
    });

    test('typed map pattern', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('map')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .map(
                    {literal('key'): .var_('v')},
                    type: (refer('String'), refer('dynamic')),
                  )
                  ..body = refer('print').call([refer('v')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (map) {
            case <String, dynamic>{'key': var v}:
              print(v);
          }
        '''),
      );
    });

    test('record pattern with single positional field', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('record')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .record(positional: [.var_('a')])
                  ..body = refer('print').call([refer('a')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (record) {
            case (var a,):
              print(a);
          }
        '''),
      );
    });

    test('record pattern with positional and named fields', () {
      expect(
        SwitchStatement(
          (b) => b
            ..value = refer('record')
            ..cases.add(
              .new(
                (b) => b
                  ..pattern = .record(
                    positional: [.var_('a')],
                    named: {'b': .var_('b'), 'c': .typed('c', refer('int'))},
                  )
                  ..body = refer('print').call([refer('a')]).statement,
              ),
            ),
        ),
        equalsDart(r'''
          switch (record) {
            case (var a, b: var b, c: int c):
              print(a);
          }
        '''),
      );
    });

    test('type check / empty object pattern', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('shape')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .object(refer('Square'))
                  ..body = literal('square'),
              ),
              .new(
                (b) => b
                  ..pattern = .object(refer('Circle'))
                  ..body = literal('circle'),
              ),
              .new(
                (b) => b
                  ..pattern = .wildcard
                  ..body = literal('unknown'),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (shape) {
            Square() => 'square',
            Circle() => 'circle',
            _ => 'unknown',
          }
        '''),
      );
    });

    test('object pattern with fields', () {
      expect(
        SwitchExpression(
          (b) => b
            ..value = refer('shape')
            ..cases.addAll([
              .new(
                (b) => b
                  ..pattern = .object(
                    refer('Square'),
                    named: {'length': .var_('l')},
                  )
                  ..body = refer('l').operatorMultiply(refer('l')),
              ),
              .new(
                (b) => b
                  ..pattern = .object(
                    refer('Circle'),
                    named: {'radius': .var_('r')},
                  )
                  ..body = refer('r').operatorMultiply(refer('r')),
              ),
            ]),
        ),
        equalsDart(r'''
          switch (shape) {
            Square(length: var l) => l * l,
            Circle(radius: var r) => r * r,
          }
        '''),
      );
    });
  });
}
