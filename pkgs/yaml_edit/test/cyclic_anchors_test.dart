// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('Cyclic AST equality (deepEquals, deepHashCode)', () {
    test('cyclic list equality and hashCode', () {
      final l1 = loadYaml('&a [*a]');
      final l2 = loadYaml('&b [*b]');
      final l3 = loadYaml('&c [1, *c]');
      final l4 = loadYaml('&d [2, *d]');
      final l5 = loadYaml('&e [1, *e]');

      expect(deepEquals(l1, l2), isTrue);
      expect(deepHashCode(l1), equals(deepHashCode(l2)));

      expect(deepEquals(l3, l5), isTrue);
      expect(deepHashCode(l3), equals(deepHashCode(l5)));

      expect(deepEquals(l3, l4), isFalse);
      expect(deepEquals(l1, l3), isFalse);
      expect(deepEquals(l1, [1]), isFalse);
    });

    test('cyclic map equality and hashCode', () {
      final m1 = loadYaml('&a { self: *a }');
      final m2 = loadYaml('&b { self: *b }');
      final m3 = loadYaml('&c { self: *c, val: 1 }');
      final m4 = loadYaml('&d { self: *d, val: 1 }');
      final m5 = loadYaml('&e { self: *e, val: 2 }');

      expect(deepEquals(m1, m2), isTrue);
      expect(deepHashCode(m1), equals(deepHashCode(m2)));

      expect(deepEquals(m3, m4), isTrue);
      expect(deepHashCode(m3), equals(deepHashCode(m4)));

      expect(deepEquals(m3, m5), isFalse);
      expect(deepEquals(m1, m3), isFalse);
    });

    test('mutually recursive maps equality and hashCode', () {
      final m1 = loadYaml('&a { b: &b { a: *a } }');
      final m2 = loadYaml('&x { b: &y { a: *x } }');
      final m3 = loadYaml('&x { b: &y { a: *x, diff: true } }');

      expect(deepEquals(m1, m2), isTrue);
      expect(deepHashCode(m1), equals(deepHashCode(m2)));
      expect(deepEquals(m1, m3), isFalse);
    });

    test('wrapAsYamlNode guards against cyclic YamlNode', () {
      final l1 = loadYaml('&a [*a]');
      final m1 = loadYaml('&a { self: *a }');

      expect(() => wrapAsYamlNode(l1), returnsNormally);
      expect(() => wrapAsYamlNode(m1), returnsNormally);
    });
  });

  group('AliasBehavior.disallow with cyclic structures', () {
    test('rejects mutations on cyclic list', () {
      final doc = YamlEditor('&list [ *list ]');
      expect(() => doc.update([0], 'foo'), throwsAliasException);
      expect(() => doc.remove([0]), throwsAliasException);
    });

    test('rejects mutations on cyclic map', () {
      final doc = YamlEditor('''
a: &node
  val: 1
  self: *node
''');
      expect(() => doc.update(['a', 'val'], 2), throwsAliasException);
      expect(() => doc.update(['a', 'self'], 'other'), throwsAliasException);
      expect(() => doc.remove(['a', 'self']), throwsAliasException);
    });

    test('rejects removing cyclic anchor definition', () {
      final doc = YamlEditor('''
a: &node
  self: *node
b: 1
''');
      expect(() => doc.remove(['a']), throwsAliasException);
    });
  });

  group('AliasBehavior.reference with cyclic structures', () {
    test('updating cyclic map anchor definition without hanging', () {
      final doc = YamlEditor(
        '''
a: &node
  val: 1
  self: *node
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], {'val': 2});
      expect(doc.parseAt(['a', 'val']).value, equals(2));
      expect(doc.toString(), equals('''
a: &node
  val: 2'''));
    });

    test('updating child property of cyclic anchor definition', () {
      final doc = YamlEditor(
        '''
a: &node
  val: 1
  self: *node
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a', 'val'], 2);
      expect(doc.parseAt(['a', 'val']).value, equals(2));
      expect(doc.parseAt(['a', 'self', 'val']).value, equals(2));
      expect(doc.toString(), equals('''
a: &node
  val: 2
  self: *node
'''));

      doc.update(['a', 'self', 'val'], 3);
      expect(doc.parseAt(['a', 'val']).value, equals(3));
      expect(doc.parseAt(['a', 'self', 'val']).value, equals(3));
      expect(doc.toString(), equals('''
a: &node
  val: 3
  self: *node
'''));
    });

    test('updating cyclic list anchor definition without hanging', () {
      final doc = YamlEditor(
        '''
a: &list
  - 1
  - *list
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], [10, 20]);
      expect(doc.parseAt(['a', 0]).value, equals(10));
      expect(doc.parseAt(['a', 1]).value, equals(20));
      expect(doc.toString(), equals('''
a: &list
  - 10
  - 20'''));
    });

    test('replacing cyclic anchor definition with scalar preserves anchor tag',
        () {
      final doc = YamlEditor(
        '''
a: &node
  self: *node
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], 'leaf_value');
      expect(doc.parseAt(['a']).value, equals('leaf_value'));
      expect(doc.toString(), equals('''
a: &node leaf_value'''));
    });
  });

  group('Removing anchor with unrelated cyclic structure', () {
    test('removes anchor in doc with cyclic list without infinite loop', () {
      final doc = YamlEditor(
        '''
cyclic: &loop
  - *loop
target: &toRemove
  name: Alice
other: 123
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['target']);
      expect(doc.parseAt(['other']).value, equals(123));
      expect(doc.parseAt(['cyclic', 0]), isNotNull);
      expect(doc.toString(), equals('''
cyclic: &loop
  - *loop
other: 123
'''));
    });

    test('removes anchor in doc with cyclic map without infinite loop', () {
      final doc = YamlEditor(
        '''
cyclic: &loop
  self: *loop
target: &toRemove
  name: Bob
other: 456
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['target']);
      expect(doc.parseAt(['other']).value, equals(456));
      expect(doc.parseAt(['cyclic', 'self']), isNotNull);
      expect(doc.toString(), equals('''
cyclic: &loop
  self: *loop
other: 456
'''));
    });
  });
}
