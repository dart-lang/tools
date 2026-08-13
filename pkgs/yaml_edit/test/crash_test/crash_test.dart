// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'fuzzer.dart';

/// Files with tests that are broken, so we have to skip them
final _skippedFiles = [
  'anchors_aliases.yaml',
  'block_strings.yaml',
  'complex_keys.yaml',
  'complex.yaml',
  'deep_nesting_comments_1.yaml',
  'deep_nesting_comments_2.yaml',
  'deep_nesting.yaml',
  'empty_nodes.yaml',
  'explicit_key_value.yaml',
  'flow_block_mix.yaml',
  'mangled_json.yaml',
  'simple_comments.yaml',
  'tabs_and_whitespace.yaml',
  'tags.yaml',
  'tricky_strings.yaml',
];

/// The crash tests will attempt to enumerate all JSON paths in each input
/// document and then proceed to make arbitrary mutations trying to see if
/// [YamlEditor] will crash. Arbitrary mutations include:
///  - Remove each JSON path
///  - Prepend and append to each list and map.
///  - Set each string to 'hello world'
///  - Set all numbers to 42
///
/// Input documents are loaded from: test/crash_test/testdata/*.yaml
Future<void> main() async {
  final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:yaml_edit/yaml_edit.dart'));

  final testdataUri = packageUri!.resolve('../test/crash_test/testdata/');
  final testFiles = Directory.fromUri(testdataUri)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList();

  for (final f in testFiles) {
    final fileName = f.uri.pathSegments.last;
    final input = f.readAsStringSync();
    final root = YamlEditor(input);

    test('$fileName is valid YAML', () {
      loadYamlNode(input);
    });

    if (_skippedFiles.contains(fileName)) {
      test(
        'crash_test.dart for $fileName',
        () {},
        skip: 'Known failures in "$fileName"',
      );
      continue;
    }

    for (final (path, node) in allJsonPaths(root.parseAt([]))) {
      testJsonPath(fileName, input, path, node);
    }
  }
}
