// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

final _testStrings = [
  "this is a fairly' long string with\nline breaks",
  'whitespace\n after line breaks',
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
  //ScalarStyle.FOLDED, // TODO: Fix this test case!
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
