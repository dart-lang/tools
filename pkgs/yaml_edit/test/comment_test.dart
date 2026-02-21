// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('updateComment', () {
    test('adds comment for scalar map value', () {
      final doc = YamlEditor('a: 1\n');

      doc.updateComment(['a'], 'auto-generated');

      expect(doc.toString(), equals('a: 1 # auto-generated\n'));
      expectYamlBuilderValue(doc, {'a': 1});
    });

    test('updates existing inline comment', () {
      final doc = YamlEditor('a: 1 # old\n');

      doc.updateComment(['a'], '# new');

      expect(doc.toString(), equals('a: 1 # new\n'));
      expectYamlBuilderValue(doc, {'a': 1});
    });

    test('removes existing inline comment', () {
      final doc = YamlEditor('a: 1 # old\n');

      doc.updateComment(['a'], null);

      expect(doc.toString(), equals('a: 1\n'));
      expectYamlBuilderValue(doc, {'a': 1});
    });

    test('adds comment for empty map value', () {
      final doc = YamlEditor('a:\n');

      doc.updateComment(['a'], 'generated');

      expect(doc.toString(), equals('a: # generated\n'));
      expectYamlBuilderValue(doc, {'a': null});
    });

    test('adds comment for list item', () {
      final doc = YamlEditor('- one\n');

      doc.updateComment([0], 'first');

      expect(doc.toString(), equals('- one # first\n'));
      expectYamlBuilderValue(doc, ['one']);
    });

    test('throws for non-empty block collections', () {
      final doc = YamlEditor('''
a:
  b: 1
''');

      expect(() => doc.updateComment(['a'], 'not supported'),
          throwsUnsupportedError);
    });

    test('supports flow collections', () {
      final doc = YamlEditor('a: {b: 1}\n');

      doc.updateComment(['a'], 'generated');

      expect(doc.toString(), equals('a: {b: 1} # generated\n'));
      expectYamlBuilderValue(doc, {
        'a': {'b': 1}
      });
    });
  });
}
