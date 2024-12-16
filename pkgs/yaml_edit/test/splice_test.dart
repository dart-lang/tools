// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  test(
      'throws RangeError if invalid index + deleteCount combination is '
      'passed in', () {
    final doc = YamlEditor('[0, 0]');
    expect(() => doc.spliceList([], 1, 5, [1, 2]), throwsRangeError);
  });

  group('block list', () {
    test('(1)', () {
      final doc = YamlEditor('''
- 0
- 0
''');
      final nodes = doc.spliceList([], 1, 1, [1, 2]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));

      expectDeepEquals(nodes.toList(), [0]);
    });

    test('(2)', () {
      final doc = YamlEditor('''
- 0
- 0
''');
      final nodes = doc.spliceList([], 0, 2, [0, 1, 2]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));

      expectDeepEquals(nodes.toList(), [0, 0]);
    });

    test('(3)', () {
      final doc = YamlEditor('''
- Jan
- March
- April
- June
''');
      final nodes = doc.spliceList([], 1, 0, ['Feb']);
      expect(doc.toString(), equals('''
- Jan
- Feb
- March
- April
- June
'''));

      expectDeepEquals(nodes.toList(), []);

      final nodes2 = doc.spliceList([], 4, 1, ['May']);
      expect(doc.toString(), equals('''
- Jan
- Feb
- March
- April
- May
'''));

      expectDeepEquals(nodes2.toList(), ['June']);
    });

    test('nested block list (inline)', () {
      final doc = YamlEditor('''
- - Jan
  - Tuesday
  - April
''');

      final nodes = doc.spliceList([0], 1, 1, ['Feb', 'March']);

      expectDeepEquals(nodes.toList(), ['Tuesday']);

      expect(doc.toString(), equals('''
- - Jan
  - Feb
  - March
  - April
'''));
    });

    test('nested block list (inline with multiple new lines)', () {
      final doc = YamlEditor('''
- 




  - Jan
  - Tuesday
  - April
''');

      final nodes = doc.spliceList([0], 1, 1, ['Feb', 'March']);

      expectDeepEquals(nodes.toList(), ['Tuesday']);

      expect(doc.toString(), equals('''
- 




  - Jan
  - Feb
  - March
  - April
'''));
    });

    test('update before nested list', () {
      final doc = YamlEditor('''
key:
  - value
  - another
  - - nested
    - continued
''');

      final nodes = doc.spliceList(['key'], 2, 0, ['spliced']);

      expectDeepEquals(nodes.toList(), []);

      expect(doc.toString(), equals('''
key:
  - value
  - another
  - spliced
  - - nested
    - continued
'''));
    });

    test('replace nested block', () {
      final doc = YamlEditor('''
key:
  - value
  - another
  - - nested
    - continued
''');

      final nodes = doc.spliceList(['key'], 2, 1, ['spliced']);

      expectDeepEquals(nodes.toList(), [
        ['nested', 'continued'],
      ]);

      expect(doc.toString(), equals('''
key:
  - value
  - another
  - spliced
'''));
    });
  });

  group('flow list', () {
    test('(1)', () {
      final doc = YamlEditor('[0, 0]');
      final nodes = doc.spliceList([], 1, 1, [1, 2]);
      expect(doc.toString(), equals('[0, 1, 2]'));

      expectDeepEquals(nodes.toList(), [0]);
    });

    test('(2)', () {
      final doc = YamlEditor('[0, 0]');
      final nodes = doc.spliceList([], 0, 2, [0, 1, 2]);
      expect(doc.toString(), equals('[0, 1, 2]'));

      expectDeepEquals(nodes.toList(), [0, 0]);
    });
  });
}
