// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('AliasBehavior.disallow (default)', () {
    test('throws AliasException on any alias touch', () {
      final doc = YamlEditor('''
a: &user
  name: Alice
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
  name: Alice
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Alice
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
  name: Alice
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Alice
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

    test('replacing anchor definition with block map preserves anchor tag', () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], {'first': 'Mark', 'last': 'McGwire'});
      expect(doc.toString(), equals('''
a: &SS
  first: Mark
  last: McGwire
b: *SS
'''));
      expect(doc.parseAt(['b', 'first']).value, equals('Mark'));
    });

    test('replacing anchor definition with block list preserves anchor tag',
        () {
      final doc = YamlEditor(
        '''
a: &SS Sammy Sosa
b: *SS
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['a'], ['Mark', 'McGwire']);
      expect(doc.toString(), equals('''
a: &SS
  - Mark
  - McGwire
b: *SS
'''));
      expect(doc.parseAt(['b', 0]).value, equals('Mark'));
    });

    test('replacing flow map anchor definition preserves anchor tag and space',
        () {
      final doc = YamlEditor(
        '{a: &user {name: Alice}, b: *user}',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(
          ['a'],
          wrapAsYamlNode({'name': 'Bob'},
              collectionStyle: CollectionStyle.FLOW));
      expect(doc.toString(), equals('{a: &user {name: Bob}, b: *user}'));
      expect(doc.parseAt(['b', 'name']).value, equals('Bob'));
    });

    test('replacing flow list anchor definition preserves anchor tag and space',
        () {
      final doc = YamlEditor(
        '[&nums [1, 2], *nums]',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(
          [0], wrapAsYamlNode([3, 4], collectionStyle: CollectionStyle.FLOW));
      expect(doc.toString(), equals('[&nums [3, 4], *nums]'));
      expect(doc.parseAt([1, 0]).value, equals(3));
    });

    test(
        'operations with YamlNode keys do not throw null errors in '
        'isAnchorDefinition', () {
      final doc = YamlEditor(
        '''
? &key [1, 2]
: &val [3, 4]
alias_val: *val
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['alias_val', 0], 99);
      expect(doc.parseAt(['alias_val', 0]).value, equals(99));
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

    test('list insert and splice via alias reference redirect to anchor list',
        () {
      final doc = YamlEditor(
        '''
list1: &nums
  - 1
  - 3
list2: *nums
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.insertIntoList(['list2'], 1, 2);
      expect(doc.toString(), equals('''
list1: &nums
  - 1
  - 2
  - 3
list2: *nums
'''));

      doc.spliceList(['list2'], 1, 2, [8, 9]);
      expect(doc.toString(), equals('''
list1: &nums
  - 1
  - 8
  - 9
list2: *nums
'''));
    });

    test('remove element from list via alias reference updates anchor list',
        () {
      final doc = YamlEditor(
        '''
list1: &nums
  - 1
  - 2
list2: *nums
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['list2', 0]);
      expect(doc.toString(), equals('''
list1: &nums
  - 2
list2: *nums
'''));
    });

    test('flow map alias reference updates cleanly under reference', () {
      final doc = YamlEditor(
        '''
a: &user { name: Alice, role: dev }
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.parseAt(['a', 'role']).value, equals('lead'));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('multiple alias references share anchor updates under reference', () {
      final doc = YamlEditor(
        '''
a: &user
  role: dev
b: *user
c: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.parseAt(['a', 'role']).value, equals('lead'));
      expect(doc.parseAt(['c', 'role']).value, equals('lead'));
    });

    test('removing anchor definition succeeds after all references are removed',
        () {
      final doc = YamlEditor(
        '''
a: &user
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['b']);
      doc.remove(['a']);
      expect(doc.toString(), equals('{}\n'));
    });
  });

  group('AliasBehavior.copyOnWrite', () {
    test('mutating child via alias reference materializes copy inline', () {
      final doc = YamlEditor(
        '''
a: &user
  name: Alice
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Alice
  role: dev
b:
  name: Alice
  role: lead
'''));
      expect(doc.parseAt(['a', 'role']).value, equals('dev'));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
    });

    test('mutating child via anchor definition updates template in place', () {
      final doc = YamlEditor(
        '''
a: &user
  name: Alice
  role: dev
b: *user
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['a', 'role'], 'lead');
      expect(doc.toString(), equals('''
a: &user
  name: Alice
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

    test('list element removal via alias reference materializes copy', () {
      final doc = YamlEditor(
        '''
list1: &nums
  - 1
  - 2
list2: *nums
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.remove(['list2', 0]);
      expect(doc.toString(), equals('''
list1: &nums
  - 1
  - 2
list2:
  - 2
'''));
    });

    test('multiple alias references decouple individually under copyOnWrite',
        () {
      final doc = YamlEditor(
        '''
a: &user
  role: dev
b: *user
c: *user
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['b', 'role'], 'lead');
      expect(doc.parseAt(['a', 'role']).value, equals('dev'));
      expect(doc.parseAt(['b', 'role']).value, equals('lead'));
      expect(doc.parseAt(['c', 'role']).value, equals('dev'));
    });

    test('copyOnWrite unfolds top alias shallowly, preserving nested aliases',
        () {
      final doc = YamlEditor(
        '''
base_env: &env
  REGION: us-central1
  ZONE: us-central1-a

base_job: &job
  timeout: 30
  env: *env

custom_job: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      // Mutating custom_job.timeout unfolds custom_job but leaves env: *env
      // intact.
      doc.update(['custom_job', 'timeout'], 45);
      expect(doc.toString(), equals('''
base_env: &env
  REGION: us-central1
  ZONE: us-central1-a

base_job: &job
  timeout: 30
  env: *env

custom_job:
  timeout: 45
  env: *env
'''));

      // Updating base_env propagates to custom_job.env via the preserved *env
      // alias.
      doc.update(['base_env', 'REGION'], 'us-east1');
      expect(
          doc.parseAt(['base_job', 'env', 'REGION']).value, equals('us-east1'));
      expect(doc.parseAt(['custom_job', 'env', 'REGION']).value,
          equals('us-east1'));

      // Mutating custom_job.env.ZONE now unfolds *env locally on-demand.
      doc.update(['custom_job', 'env', 'ZONE'], 'us-central1-b');
      expect(doc.parseAt(['base_env', 'ZONE']).value, equals('us-central1-a'));
      expect(doc.parseAt(['custom_job', 'env', 'ZONE']).value,
          equals('us-central1-b'));
    });
  });
}
