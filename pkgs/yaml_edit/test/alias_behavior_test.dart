// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('AliasBehavior.disallow (default)', () {
    test('throws AliasException on any alias touch in maps', () {
      final doc = YamlEditor('''
a: &user
  name: Alice
b: *user
''');
      expect(() => doc.update(['b', 'name'], 'John'), throwsAliasException);
      expect(() => doc.update(['a', 'name'], 'John'), throwsAliasException);
      expect(() => doc.remove(['b']), throwsAliasException);
    });

    test('throws AliasException on list element mutations and removals', () {
      final doc = YamlEditor('''
- &item 1
- *item
''');
      expect(() => doc.update([1], 2), throwsAliasException);
      expect(() => doc.update([0], 2), throwsAliasException);
      expect(() => doc.remove([1]), throwsAliasException);
      expect(() => doc.remove([0]), throwsAliasException);
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

    test('locates alias span across intervening comments', () {
      final doc = YamlEditor(
        '''
a: &val
  x: 1
b: # comment before alias
  *val
''',
        aliasBehavior: AliasBehavior.reference,
      );

      final trueSpan = doc.getTrueSpan(doc.parseAt([]), 'b');
      expect(trueSpan.text, equals('*val'));

      doc.update(['b', 'x'], 2);
      expect(doc.parseAt(['a', 'x']).value, equals(2));
      expect(doc.parseAt(['b', 'x']).value, equals(2));

      final doc2 = YamlEditor(
        '''
a: &scalar 1
b: # comment before alias
  *scalar
''',
        aliasBehavior: AliasBehavior.reference,
      );
      doc2.update(['b'], 2);
      expect(doc2.parseAt(['a']).value, equals(1));
      expect(doc2.parseAt(['b']).value, equals(2));
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

    test('copyOnWrite strips nested sub-anchor definitions when unfolding', () {
      final doc = YamlEditor(
        '''
template: &job
  timeout: &t 30
  env: prod

custom_job: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom_job', 'env'], 'dev');
      expect(doc.toString(), equals('''
template: &job
  timeout: &t 30
  env: prod

custom_job:
  timeout: 30
  env: dev
'''));
      expect(doc.parseAt(['template', 'timeout']).value, equals(30));
      expect(doc.parseAt(['custom_job', 'timeout']).value, equals(30));
    });

    test('copyOnWrite inlines intra-template aliases and strips sub-anchors',
        () {
      final doc = YamlEditor(
        '''
base: &job
  timeout: &d 30
  task: *d

custom: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom', 'timeout'], 45);
      expect(doc.toString(), equals('''
base: &job
  timeout: &d 30
  task: *d

custom:
  timeout: 45
  task: 30
'''));
      expect(doc.parseAt(['base', 'timeout']).value, equals(30));
      expect(doc.parseAt(['base', 'task']).value, equals(30));
      expect(doc.parseAt(['custom', 'timeout']).value, equals(45));
      expect(doc.parseAt(['custom', 'task']).value, equals(30));
    });

    test('copyOnWrite inlines intra-template aliases, preserving extra aliases',
        () {
      final doc = YamlEditor(
        '''
base_env: &env
  REGION: us-central1
  ZONE: us-central1-a

base_job: &job
  timeout: &d 30
  task: *d
  env: *env

custom_job: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom_job', 'timeout'], 45);
      expect(doc.toString(), equals('''
base_env: &env
  REGION: us-central1
  ZONE: us-central1-a

base_job: &job
  timeout: &d 30
  task: *d
  env: *env

custom_job:
  timeout: 45
  task: 30
  env: *env
'''));

      // Updating extra-template anchor base_env propagates to custom_job.env
      // via preserved *env.
      doc.update(['base_env', 'REGION'], 'us-east1');
      expect(
          doc.parseAt(['base_job', 'env', 'REGION']).value, equals('us-east1'));
      expect(doc.parseAt(['custom_job', 'env', 'REGION']).value,
          equals('us-east1'));

      // Mutating custom_job.env.ZONE unfolds *env locally on-demand.
      doc.update(['custom_job', 'env', 'ZONE'], 'us-central1-b');
      expect(doc.parseAt(['base_env', 'ZONE']).value, equals('us-central1-a'));
      expect(doc.parseAt(['custom_job', 'env', 'ZONE']).value,
          equals('us-central1-b'));
    });

    test(
        'subsequent mutation to base template updates base without affecting '
        'decoupled copy or failing assertions', () {
      final doc = YamlEditor(
        '''
base: &job
  timeout: &d 30
  task: *d

custom: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom', 'timeout'], 45);
      expect(doc.parseAt(['custom', 'task']).value, equals(30));

      // Updating base updates base but does not affect decoupled copy or
      // fail assertions.
      doc.update(['base', 'timeout'], 50);
      expect(doc.parseAt(['base', 'timeout']).value, equals(50));
      expect(doc.parseAt(['base', 'task']).value, equals(50));
      expect(doc.parseAt(['custom', 'timeout']).value, equals(45));
      expect(doc.parseAt(['custom', 'task']).value, equals(30));
      expect(doc.toString(), equals('''
base: &job
  timeout: &d 50
  task: *d

custom:
  timeout: 45
  task: 30
'''));
    });

    test(
        'subsequent removal of base template succeeds cleanly without '
        'AliasException or dangling references', () {
      final doc = YamlEditor(
        '''
base: &job
  timeout: &d 30
  task: *d

custom: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom', 'timeout'], 45);
      expect(doc.parseAt(['custom', 'task']).value, equals(30));

      // Removing base succeeds cleanly because custom has no dangling
      // references to &job or &d.
      expect(() => doc.remove(['base']), returnsNormally);
      expect(doc.parseAt(['custom', 'timeout']).value, equals(45));
      expect(doc.parseAt(['custom', 'task']).value, equals(30));
      expect(() => doc.parseAt(['base']), throwsArgumentError);
      expect(doc.toString(), equals('''
custom:
  timeout: 45
  task: 30
'''));
    });

    test(
        'flow style intra-template aliases expand inline and allow cleanly '
        'removing base', () {
      final doc = YamlEditor(
        '''
base: &job { def: &d 30, task: *d }
custom: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom', 'def'], 40);
      expect(doc.toString(), equals('''
base: &job { def: &d 30, task: *d }
custom: { def: 40, task: 30 }
'''));

      expect(() => doc.remove(['base']), returnsNormally);
      expect(doc.parseAt(['custom', 'def']).value, equals(40));
      expect(doc.parseAt(['custom', 'task']).value, equals(30));
      expect(doc.toString(), equals('''
custom: { def: 40, task: 30 }
'''));
    });

    test('copyOnWrite unfolds alias element inside a list', () {
      final doc = YamlEditor(
        '''
items:
  - &item
    foo: 1
    bar: 2
other:
  - *item
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['other', 0, 'foo'], 42);
      expect(doc.parseAt(['items', 0, 'foo']).value, equals(1));
      expect(doc.parseAt(['other', 0, 'foo']).value, equals(42));
      expect(doc.parseAt(['other', 0, 'bar']).value, equals(2));
    });

    test('copyOnWrite inlines intra-template sub-anchors defined within a list',
        () {
      final doc = YamlEditor(
        '''
tpl: &tpl
  items:
    - &sub 10
  ref: *sub
copy: *tpl
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['copy', 'items', 0], 99);
      expect(doc.parseAt(['tpl', 'items', 0]).value, equals(10));
      expect(doc.parseAt(['tpl', 'ref']).value, equals(10));
      expect(doc.parseAt(['copy', 'items', 0]).value, equals(99));
      expect(doc.parseAt(['copy', 'ref']).value, equals(10));

      doc.remove(['tpl']);
      expect(doc.parseAt(['copy', 'items', 0]).value, equals(99));
      expect(doc.parseAt(['copy', 'ref']).value, equals(10));
    });

    test(
        'copyOnWrite inlines intra-template multi-line block collection '
        'sub-anchors', () {
      final doc = YamlEditor(
        '''
tpl: &tpl
  sub: &sub
    x: 1
    y: 2
  ref: *sub
copy: *tpl
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['copy', 'ref', 'x'], 99);
      expect(doc.parseAt(['tpl', 'sub', 'x']).value, equals(1));
      expect(doc.parseAt(['copy', 'ref', 'x']).value, equals(99));
      expect(doc.parseAt(['copy', 'ref', 'y']).value, equals(2));
      expect(doc.parseAt(['copy', 'sub', 'x']).value, equals(1));

      doc.remove(['tpl']);
      expect(doc.parseAt(['copy', 'ref', 'x']).value, equals(99));
    });
  });

  group('List splicing, insertion, and comment preservation', () {
    test('spliceList and insertIntoList on aliased list under reference', () {
      final doc = YamlEditor(
        '''
base: &list
  - a
  - b
  - c
consumer: *list
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.spliceList(['consumer'], 1, 1, ['x', 'y']);
      expect(doc.parseAt(['base', 1]).value, equals('x'));
      expect(doc.parseAt(['base', 2]).value, equals('y'));
      expect(doc.parseAt(['consumer', 1]).value, equals('x'));

      doc.insertIntoList(['consumer'], 0, 'first');
      expect(doc.parseAt(['base', 0]).value, equals('first'));
      expect(doc.parseAt(['consumer', 0]).value, equals('first'));
    });

    test('spliceList and insertIntoList on aliased list under copyOnWrite', () {
      final doc = YamlEditor(
        '''
base: &list
  - a
  - b
  - c
consumer: *list
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.spliceList(['consumer'], 1, 1, ['x', 'y']);
      expect(doc.parseAt(['base', 1]).value, equals('b'));
      expect(doc.parseAt(['consumer', 1]).value, equals('x'));
      expect(doc.parseAt(['consumer', 2]).value, equals('y'));

      doc.insertIntoList(['consumer'], 0, 'first');
      expect(doc.parseAt(['base', 0]).value, equals('a'));
      expect(doc.parseAt(['consumer', 0]).value, equals('first'));
    });

    test('preserves inline and header comments during copyOnWrite unfolding',
        () {
      final doc = YamlEditor(
        '''
# Job template definition
template: &job
  # Execution timeout
  timeout: 30 # default
  retries: 2

custom: *job
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['custom', 'retries'], 5);
      expect(doc.toString(), contains('# Execution timeout'));
      expect(doc.toString(), contains('# default'));
      expect(doc.parseAt(['custom', 'timeout']).value, equals(30));
      expect(doc.parseAt(['custom', 'retries']).value, equals(5));
    });
  });

  group('isAnchorDefinition', () {
    test('identifies anchor definitions in maps and lists', () {
      final doc = YamlEditor('''
map:
  a: &mapAnchor val
  b: *mapAnchor
  c: plain
list:
  - &listAnchor 10
  - *listAnchor
  - 20
''');
      final map = doc.parseAt(['map']);
      expect(doc.isAnchorDefinition(map, 'a'), isTrue);
      expect(doc.isAnchorDefinition(map, 'b'), isFalse);
      expect(doc.isAnchorDefinition(map, 'c'), isFalse);

      final list = doc.parseAt(['list']);
      expect(doc.isAnchorDefinition(list, 0), isTrue);
      expect(doc.isAnchorDefinition(list, 1), isFalse);
      expect(doc.isAnchorDefinition(list, 2), isFalse);
    });
  });

  group('Block map header preservation during removal', () {
    test('preserves tag and anchor when removing first entry', () {
      final doc = YamlEditor(
        '''
parent: !!map &mapAnchor
  first: 1
  second: 2
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['parent', 'first']);
      expect(doc.toString(), equals('''
parent: !!map &mapAnchor
  second: 2
'''));
      expect(doc.parseAt(['parent', 'second']).value, equals(2));
    });

    test('preserves anchor and tag when removing first entry', () {
      final doc = YamlEditor(
        '''
parent: &mapAnchor !!map
  first: 1
  second: 2
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.remove(['parent', 'first']);
      expect(doc.toString(), equals('''
parent: &mapAnchor !!map
  second: 2
'''));
      expect(doc.parseAt(['parent', 'second']).value, equals(2));
    });

    test('preserves map tag without anchor when removing first entry', () {
      final doc = YamlEditor('''
parent: !!map
  first: 1
  second: 2
''');

      doc.remove(['parent', 'first']);
      expect(doc.toString(), equals('''
parent: !!map
  second: 2
'''));
      expect(doc.parseAt(['parent', 'second']).value, equals(2));
    });

    test('correctly removes first key when the key has an anchor', () {
      final doc = YamlEditor('''
parent:
  &keyAnchor first: 1
  second: 2
''');

      doc.remove(['parent', 'first']);
      expect(doc.toString(), equals('''
parent:
  second: 2
'''));
      expect(doc.parseAt(['parent', 'second']).value, equals(2));
    });
  });
}
