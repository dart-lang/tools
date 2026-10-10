// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('nested strings', () {
    test('folded value in a list map', () {
      const value = 'label: "quoted" # text\n[items] &anchor *alias';
      final doc = YamlEditor('''
items:
  - message: old
    keep: true
''');
      doc.update(['items', 0, 'message'],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'items': [
              {'message': value, 'keep': true}
            ]
          }));
      expect((doc.parseAt(['items', 0, 'message']) as YamlScalar).style,
          equals(ScalarStyle.FOLDED));
      expect(doc.toString(), startsWith('items:\n  - message: >-\n'));
      expect(doc.toString(), contains('label: "quoted" # text\n\n'));
      expect(
          doc.toString(), endsWith('[items] &anchor *alias\n    keep: true\n'));
    });

    test('literal value with blank line in list', () {
      const value = 'path: C:\\temp\n\n# "quoted"';
      final doc = YamlEditor('''
settings:
  messages:
    - old
    - keep
''');
      doc.update(['settings', 'messages', 0],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.LITERAL));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': [value, 'keep']
            }
          }));
      expect(
          doc.toString(),
          equals('settings:\n'
              '  messages:\n'
              '    - |-\n'
              '        path: C:\\temp\n'
              '        \n'
              '        # "quoted"\n'
              '    - keep\n'));
    });

    test('adds folded marker value to list map', () {
      const value = '# comment text\n{key: [value]}';
      final doc = YamlEditor('''
items:
  - keep: true
''');
      doc.update(['items', 0, 'message'],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'items': [
              {'keep': true, 'message': value}
            ]
          }));
      expect((doc.parseAt(['items', 0, 'message']) as YamlScalar).style,
          equals(ScalarStyle.FOLDED));
      expect(doc.toString(),
          startsWith('items:\n  - keep: true\n    message: >-\n'));
      expect(doc.toString(), contains('# comment text\n\n'));
      expect(doc.toString(), endsWith('{key: [value]}\n'));
    });

    test('appends map with literal value', () {
      const value = '&anchor: "text"\n*alias # text';
      final doc = YamlEditor('''
settings:
  messages:
    - keep
''');
      doc.appendToList(['settings', 'messages'],
          {'message': wrapAsYamlNode(value, scalarStyle: ScalarStyle.LITERAL)});

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': [
                'keep',
                {'message': value}
              ]
            }
          }));
      expect(doc.toString(), equals('''
settings:
  messages:
    - keep
    - message: |-
          &anchor: "text"
          *alias # text
'''));
    });

    test('inserts folded document markers', () {
      const value = '---\n# text\n...';
      final doc = YamlEditor('''
settings:
  messages:
    - before
    - after
''');
      doc.insertIntoList(['settings', 'messages'], 1,
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': ['before', value, 'after']
            }
          }));
      expect(doc.toString(), equals('''
settings:
  messages:
    - before
    - >-
        ---

        # text

        ...
    - after
'''));
    });

    test('quotes folded value in flow map', () {
      const value = 'key: [value]\n# text';
      final doc = YamlEditor('settings: {message: old, keep: true}\n');
      doc.update(['settings', 'message'],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {'message': value, 'keep': true}
          }));
      expect(doc.toString(),
          equals('settings: {message: "key: [value]\\n# text", keep: true}\n'));
    });

    test('quotes literal value in flow list', () {
      const value = '"quoted"\n{key: value}';
      final doc = YamlEditor('settings:\n  messages: [before, after]\n');
      doc.insertIntoList(['settings', 'messages'], 1,
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.LITERAL));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': ['before', value, 'after']
            }
          }));
      expect(
          doc.toString(),
          equals('settings:\n'
              '  messages: [before, "\\"quoted\\"\\n{key: value}", after]\n'));
    });
  });

  group('nested strings in CRLF documents', () {
    test('folded value keeps CRLF siblings', () {
      const value = 'key: value\n# "text"';
      final doc = YamlEditor('settings:\r\n  message: old\r\n  keep: true\r\n');
      doc.update(['settings', 'message'],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {'message': value, 'keep': true}
          }));
      expect((doc.parseAt(['settings', 'message']) as YamlScalar).style,
          equals(ScalarStyle.FOLDED));
      expect(doc.toString(), startsWith('settings:\r\n  message: >-'));
      expect(doc.toString(), contains('key: value\r\n\r\n'));
      expect(doc.toString(), contains('# "text"\r\n'));
      expect(doc.toString(), endsWith('\r\n  keep: true\r\n'));
    });

    test('literal CRLF value falls back to quotes', () {
      const value = 'key: value\r\n# text';
      final doc = YamlEditor('settings:\r\n  messages:\r\n    - keep\r\n');
      doc.appendToList(['settings', 'messages'],
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.LITERAL));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': ['keep', value]
            }
          }));
      expect(
          doc.toString(),
          equals('settings:\r\n  messages:\r\n'
              '    - keep\r\n    - "key: value\\r\\n# text"\r\n'));
    });

    test('folded whitespace value in CRLF list', () {
      const value = ' # text\n\t[key: value]';
      final doc = YamlEditor(
          'settings:\r\n  messages:\r\n    - before\r\n    - after\r\n');
      doc.insertIntoList(['settings', 'messages'], 1,
          wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

      expect(
          loadYaml(doc.toString()),
          equals({
            'settings': {
              'messages': ['before', value, 'after']
            }
          }));
      expect(
          doc.toString(),
          equals('settings:\r\n  messages:\r\n'
              '    - before\r\n    - " # text\\n\\t[key: value]"\r\n'
              '    - after\r\n'));
    });
  });
}
