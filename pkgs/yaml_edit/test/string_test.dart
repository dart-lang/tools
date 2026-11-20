// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

final _testStrings = [
  "this is a fairly' long string with\nline breaks",
  'whitespace\n after line breaks',
  'whitespace\n \nbetween line breaks',
  '\n line break at the start',
  'whitespace and line breaks at end 1\n ',
  'whitespace and line breaks at end 2 \n \n',
  'whitespace and line breaks at end 3 \n\n',
  'whitespace and line breaks at end 4 \n\n ',
  '\n\nline with multiple trailing line break \n\n\n\n\n',
  'whitespace\n after line break\nbefore line break',
  'tab\n\tafter line break',
  'tab\n\tafter line break\nbefore line break',
  'empty line\n\nbetween line breaks',
  'empty lines\n\n\nbetween line breaks',
  'empty line\n\n before whitespace after line break',
  'whitespace\n \n\nafter line break before empty line',
  'word',
  'foo bar',
  'foo\nbar',
  '"',
  '\'',
  'word"word',
  'word\'word'
];

final _scalarStyles = [
  ScalarStyle.ANY,
  ScalarStyle.DOUBLE_QUOTED,
  ScalarStyle.FOLDED,
  ScalarStyle.LITERAL,
  ScalarStyle.PLAIN,
  ScalarStyle.SINGLE_QUOTED,
];

/// Lines exercising the YAML line folding rules: a folded line, spaced lines
/// (starting with a space or tab), lines with trailing whitespace,
/// whitespace-only lines and an empty line.
///
/// See https://yaml.org/spec/1.2.2/#65-line-folding
const _lineKinds = ['x', ' x', '\tx', 'x ', 'x\t', ' ', '\t', ''];

/// All strings with [lineCount] lines, each taken from [_lineKinds].
List<String> _multilineStrings(int lineCount) {
  var strings = [''];
  for (var i = 0; i < lineCount; i++) {
    strings = [
      for (final string in strings)
        for (final line in _lineKinds) i == 0 ? line : '$string\n$line',
    ];
  }
  return strings;
}

void main() {
  for (final style in _scalarStyles) {
    for (var i = 0; i < _testStrings.length; i++) {
      final testString = _testStrings[i];
      test('Root $style string (${i + 1})', () {
        final yamlEditor = YamlEditor('');
        yamlEditor.update([], wrapAsYamlNode(testString, scalarStyle: style));
        final yaml = yamlEditor.toString();
        expect(loadYaml(yaml), equals(testString));
      });
    }
  }

  group('folded string', () {
    YamlEditor update(String value, {String yaml = ''}) => YamlEditor(yaml)
      ..update([], wrapAsYamlNode(value, scalarStyle: ScalarStyle.FOLDED));

    test('with line break between two folded lines', () {
      final doc = update('x\ny');
      expect(doc.toString(), equals('>-\n  x\n\n  y'));
      expect(doc.parseAt([]).value, equals('x\ny'));
    });

    test('with more-indented line between two folded lines', () {
      final doc = update('x\n z\ny');
      expect(doc.toString(), equals('>-\n  x\n   z\n  y'));
      expect(doc.parseAt([]).value, equals('x\n z\ny'));
    });

    test('with tab-indented line between two folded lines', () {
      final doc = update('x\n\tz\ny');
      expect(doc.toString(), equals('>-\n  x\n  \tz\n  y'));
      expect(doc.parseAt([]).value, equals('x\n\tz\ny'));
    });

    test('with empty line between two folded lines', () {
      final doc = update('x\n\ny');
      expect(doc.toString(), equals('>-\n  x\n  \n\n  y'));
      expect(doc.parseAt([]).value, equals('x\n\ny'));
    });

    test('with windows line endings', () {
      final doc = update('x\ny', yaml: 'old\r\n');
      expect(doc.toString(), equals('>-\r\n  x\r\n\r\n  y'));
      expect(doc.parseAt([]).value, equals('x\ny'));
    });
  });

  group('block string in nested block map', () {
    for (final style in [ScalarStyle.FOLDED, ScalarStyle.LITERAL]) {
      for (var lineCount = 2; lineCount <= 4; lineCount++) {
        test('round-trips all $lineCount-line strings as $style', () {
          for (final string in _multilineStrings(lineCount)) {
            final doc = YamlEditor('a:\n  b: old\nc: 1\n');
            doc.update(['a', 'b'], wrapAsYamlNode(string, scalarStyle: style));
            final node = doc.parseAt(['a', 'b']) as YamlScalar;
            expect(node.value, equals(string), reason: 'Document:\n$doc');
            // Block styles can encode any string that does not start or end
            // with whitespace.
            if (string.trim() == string) {
              expect(node.style, equals(style), reason: 'Document:\n$doc');
            }
            expect(doc.parseAt(['c']).value, equals(1));
          }
        });
      }
    }
  });
}
