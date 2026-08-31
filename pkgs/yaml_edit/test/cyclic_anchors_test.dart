// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

bool _supportsSelfReferentialYaml() {
  try {
    loadYaml('&a [*a]');
    return true;
  } on YamlException {
    return false;
  }
}

void main() {
  group('Cyclic Dart collection equality (deepEquals, deepHashCode)', () {
    test('cyclic list equality and hashCode', () {
      final l1 = <Object?>[];
      l1.add(l1);
      final l2 = <Object?>[];
      l2.add(l2);
      final l3 = <Object?>[1];
      l3.add(l3);
      final l4 = <Object?>[2];
      l4.add(l4);
      final l5 = <Object?>[1];
      l5.add(l5);

      expect(deepEquals(l1, l2), isTrue);
      expect(deepHashCode(l1), equals(deepHashCode(l2)));

      expect(deepEquals(l3, l5), isTrue);
      expect(deepHashCode(l3), equals(deepHashCode(l5)));

      expect(deepEquals(l3, l4), isFalse);
      expect(deepEquals(l1, l3), isFalse);
      expect(deepEquals(l1, [1]), isFalse);
    });

    test('cyclic map equality and hashCode', () {
      final m1 = <Object?, Object?>{};
      m1['self'] = m1;
      final m2 = <Object?, Object?>{};
      m2['self'] = m2;
      final m3 = <Object?, Object?>{'val': 1};
      m3['self'] = m3;
      final m4 = <Object?, Object?>{'val': 1};
      m4['self'] = m4;
      final m5 = <Object?, Object?>{'val': 2};
      m5['self'] = m5;

      expect(deepEquals(m1, m2), isTrue);
      expect(deepHashCode(m1), equals(deepHashCode(m2)));

      expect(deepEquals(m3, m4), isTrue);
      expect(deepHashCode(m3), equals(deepHashCode(m4)));

      expect(deepEquals(m3, m5), isFalse);
      expect(deepEquals(m1, m3), isFalse);
    });

    test('mutually recursive maps equality and hashCode', () {
      final a1 = <Object?, Object?>{};
      final b1 = <Object?, Object?>{'a': a1};
      a1['b'] = b1;

      final a2 = <Object?, Object?>{};
      final b2 = <Object?, Object?>{'a': a2};
      a2['b'] = b2;

      final a3 = <Object?, Object?>{};
      final b3 = <Object?, Object?>{'a': a3, 'diff': true};
      a3['b'] = b3;

      expect(deepEquals(a1, a2), isTrue);
      expect(deepHashCode(a1), equals(deepHashCode(a2)));
      expect(deepEquals(a1, a3), isFalse);
    });

    test('wrapAsYamlNode rejects cyclic Dart collections with UnsupportedError',
        () {
      final l = <Object?>[];
      l.add(l);
      expect(() => wrapAsYamlNode(l), throwsUnsupportedError);

      final m = <Object?, Object?>{};
      m['self'] = m;
      expect(() => wrapAsYamlNode(m), throwsUnsupportedError);
    });
  });

  group('Self-referential YAML structures in YamlEditor', () {
    test('handling or rejection depending on package:yaml capabilities', () {
      if (!_supportsSelfReferentialYaml()) {
        // yaml >= 3.1.4 explicitly rejects self-referential collections.
        expect(
            () => YamlEditor('&list [ *list ]'), throwsA(isA<YamlException>()));
        expect(() => YamlEditor('''
a: &node
  val: 1
  self: *node
'''), throwsA(isA<YamlException>()));
      } else {
        // package:yaml <= 3.1.3 loads self-referential collections.
        final doc = YamlEditor('&list [ *list ]');
        expect(() => doc.update([0], 'foo'), throwsAliasException);
        expect(() => doc.remove([0]), throwsAliasException);
      }
    });

    test('AliasBehavior.disallow rejects cyclic mutations if parsed', () {
      if (!_supportsSelfReferentialYaml()) return;

      final doc = YamlEditor('''
a: &node
  val: 1
  self: *node
''');
      expect(() => doc.update(['a', 'val'], 2), throwsAliasException);
      expect(() => doc.update(['a', 'self'], 'other'), throwsAliasException);
      expect(() => doc.remove(['a', 'self']), throwsAliasException);
    });

    test('AliasBehavior.reference updating cyclic anchor if parsed', () {
      if (!_supportsSelfReferentialYaml()) return;

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
  val: 2
'''));
    });

    test('replacing cyclic anchor with scalar if parsed', () {
      if (!_supportsSelfReferentialYaml()) return;

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
a: &node leaf_value
'''));
    });
  });
}
