// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('throws', () {
    test('RangeError in list if index is negative', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.update([-1], 'test'), throwsRangeError);
    });

    test('RangeError in list if index is larger than list length', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.update([2], 'test'), throwsRangeError);
    });

    test('PathError in list if attempting to set a key of a scalar', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.update([0, 'a'], 'a'), throwsPathError);
    });

    test('PathError in list if using a non-integer as index', () {
      final doc = YamlEditor("{ a: ['b', 'c'] }");
      expect(() => doc.update(['a', 'b'], 'x'), throwsPathError);
    });
  });

  group('works on top-level', () {
    test('empty document', () {
      final doc = YamlEditor('');
      doc.update([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces string in document containing only a string', () {
      final doc = YamlEditor('test');
      doc.update([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level string to map', () {
      final doc = YamlEditor('test');
      doc.update([], {'a': 1});

      expect(doc.toString(), equals('a: 1'));
      expectYamlBuilderValue(doc, {'a': 1});
    });

    test('replaces top-level list', () {
      final doc = YamlEditor('- 1');
      doc.update([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level map', () {
      final doc = YamlEditor('a: 1');
      doc.update([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level map with comment', () {
      final doc = YamlEditor('a: 1 # comment');
      doc.update([], 'replacement');

      expect(doc.toString(), equals('replacement # comment'));
      expectYamlBuilderValue(doc, 'replacement');
    });
  });

  group('replaces in', () {
    group('block map', () {
      test('(1)', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language");
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('YAML: test'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('(2)', () {
        final doc = YamlEditor('test: test');
        doc.update(['test'], []);

        expect(doc.toString(), equals('test: []'));
        expectYamlBuilderValue(doc, {'test': []});
      });

      test('empty value', () {
        final doc = YamlEditor('YAML:');
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('YAML: test'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('empty value (2)', () {
        final doc = YamlEditor('YAML :');
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('YAML : test'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('with comment', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language # comment");
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('YAML: test # comment'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('nested', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5
c: 3
''');
        doc.update(['b', 'e'], 6);

        expect(doc.toString(), equals('''
a: 1
b:
  d: 4
  e: 6
c: 3
'''));

        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {'d': 4, 'e': 6},
          'c': 3
        });
      });

      test('nested (2)', () {
        final doc = YamlEditor('''
a: 1
b: {d: 4, e: 5}
c: 3
''');
        doc.update(['b', 'e'], 6);

        expect(doc.toString(), equals('''
a: 1
b: {d: 4, e: 6}
c: 3
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {'d': 4, 'e': 6},
          'c': 3
        });
      });

      test('nested (3)', () {
        final doc = YamlEditor('''
a:
 b: 4
''');
        doc.update(['a'], true);

        expect(doc.toString(), equals('''
a: true
'''));

        expectYamlBuilderValue(doc, {'a': true});
      });

      test('nested (4)', () {
        final doc = YamlEditor('''
a: 1
''');
        doc.update([
          'a'
        ], [
          {'a': true, 'b': false}
        ]);

        expectYamlBuilderValue(doc, {
          'a': [
            {'a': true, 'b': false}
          ]
        });
      });

      test('nested (5)', () {
        final doc = YamlEditor('''
a:
  - a: 1
    b: 2
  - null
''');
        doc.update(['a', 0], false);
        expect(doc.toString(), equals('''
a:
  - false

  - null
'''));
        expectYamlBuilderValue(doc, {
          'a': [false, null]
        });
      });

      test('nested (6)', () {
        final doc = YamlEditor('''
a:
  - - 1
    - 2
  - null
''');
        doc.update(['a', 0], false);
        expect(doc.toString(), equals('''
a:
  - false

  - null
'''));
        expectYamlBuilderValue(doc, {
          'a': [false, null]
        });
      });

      test('nested (7)', () {
        final doc = YamlEditor('''
a:
  - - 0
b: false
''');
        doc.update(['a', 0], true);

        expect(doc.toString(), equals('''
a:
  - true

b: false
'''));
      });

      test('nested (8)', () {
        final doc = YamlEditor('''
a:
b: false
''');
        doc.update(['a'], {'retry': '3.0.1'});

        expect(doc.toString(), equals('''
a:
  retry: 3.0.1
b: false
'''));
      });

      test('nested (9)', () {
        final doc = YamlEditor('''
# comment
a: # comment
# comment
''');
        doc.update(['a'], {'retry': '3.0.1'});

        expect(doc.toString(), equals('''
# comment
a:
  retry: 3.0.1 # comment
# comment
'''));
      });

      test('nested scalar -> flow list', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5
c: 3
''');
        doc.update(['b', 'e'], [1, 2, 3]);

        expect(doc.toString(), equals('''
a: 1
b:
  d: 4
  e:
    - 1
    - 2
    - 3
c: 3
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {
            'd': 4,
            'e': [1, 2, 3]
          },
          'c': 3
        });
      });

      test('nested block map -> scalar', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5
c: 3
''');
        doc.update(['b'], 2);

        expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('nested block map -> scalar with comments', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5


# comment
''');
        doc.update(['b'], 2);

        expect(doc.toString(), equals('''
a: 1
b: 2


# comment
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': 2,
        });
      });

      test('nested scalar -> block map', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5
c: 3
''');
        doc.update(['b', 'e'], {'x': 3, 'y': 4});

        expect(doc.toString(), equals('''
a: 1
b:
  d: 4
  e:
    x: 3
    y: 4
c: 3
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {
            'd': 4,
            'e': {'x': 3, 'y': 4}
          },
          'c': 3
        });
      });

      test('nested block map with comments', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4
  e: 5 # comment
c: 3
''');
        doc.update(['b', 'e'], 6);

        expect(doc.toString(), equals('''
a: 1
b:
  d: 4
  e: 6 # comment
c: 3
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {'d': 4, 'e': 6},
          'c': 3
        });
      });

      test('nested block map with comments (2)', () {
        final doc = YamlEditor('''
a: 1
b:
  d: 4 # comment
# comment
  e: 5 # comment
# comment
c: 3
''');
        doc.update(['b', 'e'], 6);

        expect(doc.toString(), equals('''
a: 1
b:
  d: 4 # comment
# comment
  e: 6 # comment
# comment
c: 3
'''));
        expectYamlBuilderValue(doc, {
          'a': 1,
          'b': {'d': 4, 'e': 6},
          'c': 3
        });
      });
    });

    group('flow map', () {
      test('(1)', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('{YAML: test}'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('(2)', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(['YAML'], 'd9]zH`FoYC/>]');

        expect(doc.toString(), equals('{YAML: "d9]zH`FoYC\\/>]"}'));
        expectYamlBuilderValue(doc, {'YAML': 'd9]zH`FoYC/>]'});
      });

      test('empty value', () {
        final doc = YamlEditor('{YAML: }');
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('{YAML: test}'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('empty value (2)', () {
        final doc = YamlEditor('{YAML: , hi: bye}');
        doc.update(['YAML'], 'test');

        expect(doc.toString(), equals('{YAML: test, hi: bye}'));
        expectYamlBuilderValue(doc, {'YAML': 'test', 'hi': 'bye'});
      });

      test('with spacing', () {
        final doc = YamlEditor("{ YAML:  YAML Ain't Markup Language , "
            'XML: Extensible Markup Language , '
            'HTML: Hypertext Markup Language }');
        doc.update(['XML'], 'XML Markup Language');

        expect(
            doc.toString(),
            equals("{ YAML:  YAML Ain't Markup Language , "
                'XML: XML Markup Language, '
                'HTML: Hypertext Markup Language }'));
        expectYamlBuilderValue(doc, {
          'YAML': "YAML Ain't Markup Language",
          'XML': 'XML Markup Language',
          'HTML': 'Hypertext Markup Language'
        });
      });
    });

    group('block list', () {
      test('(1)', () {
        final doc = YamlEditor("- YAML Ain't Markup Language");
        doc.update([0], 'test');

        expect(doc.toString(), equals('- test'));
        expectYamlBuilderValue(doc, ['test']);
      });

      test('(2)', () {
        final doc = YamlEditor('''
- 1
- 
- 3
''');
        doc.update([1], 2);

        expect(doc.toString(), equals('''
- 1
- 2 
- 3
'''));
        expectYamlBuilderValue(doc, [1, 2, 3]);
      });

      test('nested (1)', () {
        final doc = YamlEditor("- YAML Ain't Markup Language");
        doc.update([0], [1, 2]);

        expect(doc.toString(), equals('- - 1\n  - 2'));
        expectYamlBuilderValue(doc, [
          [1, 2]
        ]);
      });

      test('with comment', () {
        final doc = YamlEditor("- YAML Ain't Markup Language # comment");
        doc.update([0], 'test');

        expect(doc.toString(), equals('- test # comment'));
        expectYamlBuilderValue(doc, ['test']);
      });

      test('with comment (2)', () {
        final doc = YamlEditor('''
- 1
- # comment
- 3
''');
        doc.update([1], 2);

        expect(doc.toString(), equals('''
- 1
- 2 # comment
- 3
'''));
        expectYamlBuilderValue(doc, [1, 2, 3]);
      });

      test('with comment and spaces', () {
        final doc = YamlEditor("-  YAML Ain't Markup Language  # comment");
        doc.update([0], 'test');

        expect(doc.toString(), equals('-  test  # comment'));
        expectYamlBuilderValue(doc, ['test']);
      });

      test('nested (2)', () {
        final doc = YamlEditor('''
- 0
- - 0
  - 1
  - 2
- 2
- 3
''');
        doc.update([1, 1], 4);
        expect(doc.toString(), equals('''
- 0
- - 0
  - 4
  - 2
- 2
- 3
'''));

        expectYamlBuilderValue(doc, [
          0,
          [0, 4, 2],
          2,
          3
        ]);
      });

      test('nested (3)', () {
        final doc = YamlEditor('''
- 0
- 1
''');
        doc.update([0], {'item': 'Super Hoop', 'quantity': 1});
        doc.update([1], {'item': 'BasketBall', 'quantity': 4});
        expect(doc.toString(), equals('''
- item: Super Hoop
  quantity: 1
- item: BasketBall
  quantity: 4
'''));

        expectYamlBuilderValue(doc, [
          {'item': 'Super Hoop', 'quantity': 1},
          {'item': 'BasketBall', 'quantity': 4}
        ]);
      });

      test('nested list flow map -> scalar', () {
        final doc = YamlEditor('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
        doc.update([1], 4);
        expect(doc.toString(), equals('''
- 0
- 4
- 2
- 3
'''));
        expectYamlBuilderValue(doc, [0, 4, 2, 3]);
      });

      test('nested list-map-list-number update', () {
        final doc = YamlEditor('''
- 0
- a:
   - 1
   - 2
   - 3
- 2
- 3
''');
        doc.update([1, 'a', 0], 15);
        expect(doc.toString(), equals('''
- 0
- a:
   - 15
   - 2
   - 3
- 2
- 3
'''));
        expectYamlBuilderValue(doc, [
          0,
          {
            'a': [15, 2, 3]
          },
          2,
          3
        ]);
      });
    });

    group('flow list', () {
      test('(1)', () {
        final doc = YamlEditor("[YAML Ain't Markup Language]");
        doc.update([0], 'test');

        expect(doc.toString(), equals('[test]'));
        expectYamlBuilderValue(doc, ['test']);
      });

      test('(2)', () {
        final doc = YamlEditor("[YAML Ain't Markup Language]");
        doc.update([0], [1, 2, 3]);

        expect(doc.toString(), equals('[[1, 2, 3]]'));
        expectYamlBuilderValue(doc, [
          [1, 2, 3]
        ]);
      });

      /// We cannot have empty values in a flow list.

      test('with spacing (1)', () {
        final doc = YamlEditor('[ 0 , 1 , 2 , 3 ]');
        doc.update([1], 4);

        expect(doc.toString(), equals('[ 0 , 4, 2 , 3 ]'));
        expectYamlBuilderValue(doc, [0, 4, 2, 3]);
      });
    });
  });

  group('adds to', () {
    group('flow map', () {
      test('that is empty ', () {
        final doc = YamlEditor('{}');
        doc.update(['a'], 1);
        expect(doc.toString(), equals('{a: 1}'));
        expectYamlBuilderValue(doc, {'a': 1});
      });

      test('that is empty (2)', () {
        final doc = YamlEditor('''
- {}
- []
''');
        doc.update([0, 'a'], [1]);
        expect(doc.toString(), equals('''
- {a: [1]}
- []
'''));
        expectYamlBuilderValue(doc, [
          {
            'a': [1]
          },
          []
        ]);
      });

      test('(1)', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(['XML'], 'Extensible Markup Language');

        expect(
            doc.toString(),
            '{XML: Extensible Markup Language, '
            "YAML: YAML Ain't Markup Language}");
        expectYamlBuilderValue(doc, {
          'XML': 'Extensible Markup Language',
          'YAML': "YAML Ain't Markup Language",
        });
      });

      test('spanning multiple lines with trailing comma', () {
        final doc = YamlEditor('''
{
  a: 1,
  b: 2,
}
''');
        doc.update(['c'], 3);
        expect(doc.toString(), equals('''
{
  a: 1,
  b: 2,
  c: 3,
}
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('spanning multiple lines with trailing comma and comment', () {
        final doc = YamlEditor('''
{
  a: 1,
  b: 2, # comment
}
''');
        doc.update(['c'], 3);
        expect(doc.toString(), equals('''
{
  a: 1,
  b: 2, # comment
  c: 3,
}
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('nested flow map spanning multiple lines with trailing comma', () {
        final doc = YamlEditor('''
analyzer:
  exclude:
    {
      foo: 1,
      build: 2,
    }
''');
        doc.update(['analyzer', 'exclude', 'android'], 3);
        expect(doc.toString(), equals('''
analyzer:
  exclude:
    {
      foo: 1,
      build: 2,
      android: 3,
    }
'''));
        expectYamlBuilderValue(doc, {
          'analyzer': {
            'exclude': {'foo': 1, 'build': 2, 'android': 3}
          }
        });
      });

      test('spanning multiple lines without trailing comma', () {
        final doc = YamlEditor('''
{
  a: 1,
  b: 2
}
''');
        doc.update(['c'], 3);
        expect(doc.toString(), equals('''
{
  a: 1,
  b: 2
, c: 3}
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('single line with trailing comma', () {
        final doc = YamlEditor('{a: 1, b: 2, }');
        doc.update(['c'], 3);
        expect(doc.toString(), equals('{a: 1, b: 2, c: 3,}'));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('single line with trailing comma (no space)', () {
        final doc = YamlEditor('{a: 1, b: 2,}');
        doc.update(['c'], 3);
        expect(doc.toString(), equals('{a: 1, b: 2, c: 3,}'));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
      });

      test('updating explicit key without colon succeeds', () {
        final doc = YamlEditor('{? key}');
        doc.update(['key'], 'value');
        expect(doc.toString(), equals('{? key: value}'));
        expectYamlBuilderValue(doc, {'key': 'value'});

        final doc2 = YamlEditor('{? key, foo: bar}');
        doc2.update(['key'], 'value');
        expect(doc2.toString(), equals('{? key: value, foo: bar}'));
        expectYamlBuilderValue(doc2, {'key': 'value', 'foo': 'bar'});
      });

      test('updating explicit key with colon succeeds', () {
        final doc = YamlEditor('{? key: old}');
        doc.update(['key'], 'new');
        expect(doc.toString(), equals('{? key: new}'));
        expectYamlBuilderValue(doc, {'key': 'new'});
      });
    });

    group('block map', () {
      test('(1)', () {
        final doc = YamlEditor('''
a: 1
b: 2
c: 3
''');
        doc.update(['d'], 4);
        expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      });

      test('Preserves alphabetical order single', () {
        {
          final doc = YamlEditor('''
b: 2
''');
          doc.update(['a'], 1);
          expect(doc.toString(), '''
a: 1
b: 2
''');
          expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
        }
        {
          final doc = YamlEditor('''
a: 1
''');
          doc.update(['b'], 2);
          expect(doc.toString(), '''
a: 1
b: 2
''');
          expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
        }
      });

      // Regression testing to ensure it works without leading whitespace
      test('(2)', () {
        final doc = YamlEditor('a: 1');
        doc.update(['b'], 2);
        expect(doc.toString(), equals('''a: 1
b: 2
'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
      });

      test('(3)', () {
        final doc = YamlEditor('''
a:
  aa: 1
  zz: 1
''');
        doc.update([
          'a',
          'bb'
        ], {
          'aaa': {'dddd': 'c'},
          'bbb': [0, 1, 2]
        });

        expect(doc.toString(), equals('''
a:
  aa: 1
  bb:
    aaa:
      dddd: c
    bbb:
      - 0
      - 1
      - 2
  zz: 1
'''));
        expectYamlBuilderValue(doc, {
          'a': {
            'aa': 1,
            'bb': {
              'aaa': {'dddd': 'c'},
              'bbb': [0, 1, 2]
            },
            'zz': 1
          }
        });
      });

      test('(4)', () {
        final doc = YamlEditor('''
a:
  aa: 1
  zz: 1
''');
        doc.update([
          'a',
          'bb'
        ], [
          0,
          [1, 2],
          {'aaa': 'b', 'bbb': 'c'}
        ]);

        expect(doc.toString(), equals('''
a:
  aa: 1
  bb:
    - 0
    - - 1
      - 2
    - aaa: b
      bbb: c
  zz: 1
'''));
        expectYamlBuilderValue(doc, {
          'a': {
            'aa': 1,
            'bb': [
              0,
              [1, 2],
              {'aaa': 'b', 'bbb': 'c'}
            ],
            'zz': 1
          }
        });
      });

      test('with complex keys', () {
        final doc = YamlEditor('''
? Sammy Sosa
? Ken Griff''');
        doc.update(['Mark McGwire'], null);
        expect(doc.toString(), equals('''
? Sammy Sosa
? Ken Griff
Mark McGwire: null
'''));
        expectYamlBuilderValue(
            doc, {'Sammy Sosa': null, 'Ken Griff': null, 'Mark McGwire': null});
      });

      test('updating explicit key without colon succeeds', () {
        final doc1 = YamlEditor('? key\n');
        doc1.update(['key'], 123);
        expect(doc1.toString(), equals('? key\n: 123\n'));
        expectYamlBuilderValue(doc1, {'key': 123});

        final doc2 = YamlEditor('? key');
        doc2.update(['key'], 123);
        expect(doc2.toString(), equals('? key\n: 123\n'));
        expectYamlBuilderValue(doc2, {'key': 123});

        final doc3 = YamlEditor('''
? key
foo: bar
''');
        doc3.update(['key'], 123);
        expect(doc3.toString(), equals('''
? key
: 123
foo: bar
'''));
        expectYamlBuilderValue(doc3, {'key': 123, 'foo': 'bar'});

        final doc4 = YamlEditor('''
? key # comment with : here
foo: bar
''');
        doc4.update(['key'], 123);
        expect(doc4.toString(), equals('''
? key # comment with : here
: 123
foo: bar
'''));
        expectYamlBuilderValue(doc4, {'key': 123, 'foo': 'bar'});

        final doc5 = YamlEditor('''
parent:
  ? key
  foo: bar
''');
        doc5.update(['parent', 'key'], 123);
        expect(doc5.toString(), equals('''
parent:
  ? key
  : 123
  foo: bar
'''));
        expectYamlBuilderValue(doc5, {
          'parent': {'key': 123, 'foo': 'bar'}
        });
      });

      test('updating explicit key with colon succeeds', () {
        final doc = YamlEditor('''
? key
: old
''');
        doc.update(['key'], 'new');
        expect(doc.toString(), equals('''
? key
: new
'''));
        expectYamlBuilderValue(doc, {'key': 'new'});
      });

      test('with trailing newline', () {
        final doc = YamlEditor('''
a: 1
b: 2
c: 3


''');
        doc.update(['d'], 4);
        expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4


'''));
        expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      });

      test('adds an empty map properly', () {
        final doc = YamlEditor('a: b');
        doc.update(['key'], {});
        expectYamlBuilderValue(doc, {'a': 'b', 'key': {}});
      });

      test('adds an empty map properly (2)', () {
        final doc = YamlEditor('a: b');
        doc.update(['a'], {'key': {}});
        expectYamlBuilderValue(doc, {
          'a': {'key': {}}
        });
      });

      test('adds and preserves key order (ascending)', () {
        final doc = YamlEditor('''
a: 1
b: 2
c: 3


''');

        doc.update(['d'], 4);
        expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4


'''));
      });

      test('adds at the end when no key order is present', () {
        final doc = YamlEditor('''
a: 1
c: 2
b: 3
''');

        doc.update(['d'], 4);
        expect(doc.toString(), equals('''
a: 1
c: 2
b: 3
d: 4
'''));
      });
    });

    group('empty starting document', () {
      test('empty map', () {
        final doc = YamlEditor('');
        doc.update([], {'key': {}});
        expectYamlBuilderValue(doc, {'key': {}});
      });

      test('empty map (2)', () {
        final doc = YamlEditor('');
        doc.update([], {});
        expectYamlBuilderValue(doc, {});
      });

      test('empty map (3)', () {
        final doc = YamlEditor('');
        doc.update(
          [],
          wrapAsYamlNode(
            {'key': {}},
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
        expectYamlBuilderValue(doc, {'key': {}});
      });

      test('empty map (4)', () {
        final doc = YamlEditor('');
        doc.update(
          [],
          wrapAsYamlNode(
            {},
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
        expectYamlBuilderValue(doc, {});
      });

      test('empty list', () {
        final doc = YamlEditor('');
        doc.update([], {'key': []});
        expectYamlBuilderValue(doc, {'key': []});
      });

      test('empty list (2)', () {
        final doc = YamlEditor('');
        doc.update([], []);
        expectYamlBuilderValue(doc, []);
      });

      test('empty list (3)', () {
        final doc = YamlEditor('');
        doc.update(
          [],
          wrapAsYamlNode(
            {'key': []},
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
        expectYamlBuilderValue(doc, {'key': []});
      });

      test('empty map (4)', () {
        final doc = YamlEditor('');
        doc.update(
          [],
          wrapAsYamlNode(
            [],
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
        expectYamlBuilderValue(doc, []);
      });
    });
  });

  group('quoted map keys with spaces before colon', () {
    test('preserves colon when updating double-quoted key with space', () {
      final doc = YamlEditor('''
"key" : 123
other: 456
''');
      doc.update(['key'], 789);
      expect(doc.toString(), equals('''
"key" : 789
other: 456
'''));
      expect(doc.parseAt(['key']).value, equals(789));
    });

    test('preserves colon when updating single-quoted key with space', () {
      final doc = YamlEditor('''
'my quoted key'   : 100
''');
      doc.update(['my quoted key'], 200);
      expect(doc.toString(), equals('''
'my quoted key'   : 200
'''));
      expect(doc.parseAt(['my quoted key']).value, equals(200));
    });

    test('preserves colon when replacing with block collection', () {
      final doc = YamlEditor('''
"key"  : 123
''');
      doc.update(['key'], ['a', 'b']);
      expect(doc.toString(), equals('''
"key"  :
  - a
  - b
'''));
      expect(doc.parseAt(['key', 0]).value, equals('a'));
    });
  });

  group('flow collections with comments or empty values', () {
    test('update flow list with comment containing comma and bracket', () {
      final doc = YamlEditor('[1 # comment with , and ]\n, 2]');
      doc.update([0], 'updated');
      expect(doc.parseAt([0]).value, equals('updated'));
      expect(doc.parseAt([1]).value, equals(2));
    });

    test('flow map update with comment containing comma and braces', () {
      final doc = YamlEditor('{a: 1 # comment with , and { and }\n, b: 2}');
      doc.update(['a'], 99);
      expect(doc.parseAt(['a']).value, equals(99));
      expect(doc.parseAt(['b']).value, equals(2));

      doc.update(['b'], 88);
      expect(doc.parseAt(['b']).value, equals(88));
    });

    test('flow map insert with comment containing delimiters', () {
      final doc = YamlEditor('{a: 1 # comment with , and }\n, b: 2}');
      doc.update(['c'], 3);
      expect(doc.parseAt(['a']).value, equals(1));
      expect(doc.parseAt(['b']).value, equals(2));
      expect(doc.parseAt(['c']).value, equals(3));
    });

    test('flow map update empty value without space after colon', () {
      final doc = YamlEditor('{a:}');
      doc.update(['a'], 'hello');
      expect(doc.toString(), equals('{a: hello}'));
      expect(doc.parseAt(['a']).value, equals('hello'));
    });

    test('flow map update empty value with comment', () {
      final doc = YamlEditor('{a: # comment\n, b: 1}');
      doc.update(['a'], 'hello');
      expect(doc.parseAt(['a']).value, equals('hello'));
      expect(doc.parseAt(['b']).value, equals(1));
    });
  });
}
