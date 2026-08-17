// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('AliasBehavior.disallow (default)', () {
    test('throws AliasException on any alias touch', () {
      final doc = YamlEditor('''
a: &user
  name: Sigurd
b: *user
''');
      expect(() => doc.update(['b', 'name'], 'John'), throwsAliasException);
      expect(() => doc.update(['a', 'name'], 'John'), throwsAliasException);
      expect(() => doc.remove(['b']), throwsAliasException);
    });
  });

  group('AliasBehavior.reference', () {
    test('mutating child via alias reference redirects to anchor definition',
        () {
      final doc = YamlEditor(
        '''
a: &user
  name: Sigurd
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Sigurd
  role: lead
b: *user
'''));
      expect(doc.parseAt(['a', 'role']).value, equals('lead'));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('mutating child via anchor definition propagates to references', () {
      final doc = YamlEditor(
        '''
a: &user
  name: Sigurd
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Sigurd
  role: lead
b: *user
'''));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('replacing anchor definition leaf preserves anchor tag', () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], 'Mark McGwire');
      expect(doc.toString(), equals('''
a: &SS Mark McGwire
b: *SS
'''));
      expect(doc.parseAt(['b']).value, equals('Mark McGwire'));
    });

    test('replacing alias reference leaf replaces reference token only', () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['b'], 'Mark McGwire');
      expect(doc.toString(), equals('''
a: &SS Sammy Sosa
b: Mark McGwire
'''));
      expect(doc.parseAt(['a']).value, equals('Sammy Sosa'));
    });

    test('removing alias reference leaf removes entry without affecting anchor',
        () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['b']);
      expect(doc.toString(), equals('''
a: &SS Sammy Sosa
'''));
    });

    test('removing anchor definition while referenced throws AliasException',
        () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      expect(() => doc.remove(['a']), throwsAliasException);
    });

    test('list append via alias reference redirects to anchor list', () {
      final doc = YamlEditor(
        '''
list1: &nums
  - 1
  - 2
list2: *nums
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.appendToList(['list2'], 3);
      expect(doc.toString(), equals('''
list1: &nums
  - 1
  - 2
  - 3
list2: *nums
'''));
    });
  });

  group('AliasBehavior.copyOnWrite', () {
    test('mutating child via alias reference materializes copy inline', () {
      final doc = YamlEditor(
        '''
a: &user
  name: Sigurd
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Sigurd
  role: dev
b:
  name: Sigurd
  role: lead
'''));
      expect(doc.parseAt(['a', 'role']).value, equals('dev'));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('mutating child via anchor definition updates template in place', () {
      final doc = YamlEditor(
        '''
a: &user
  name: Sigurd
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['a', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Sigurd
  role: lead
b: *user
'''));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('replacing alias reference leaf replaces reference token', () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['b'], 'Mark McGwire');
      expect(doc.toString(), equals('''
a: &SS Sammy Sosa
b: Mark McGwire
'''));
    });

    test('removing alias reference leaf deletes entry cleanly', () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.remove(['b']);
      expect(doc.toString(), equals('''
a: &SS Sammy Sosa
'''));
    });
  });
}
