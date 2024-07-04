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
}
