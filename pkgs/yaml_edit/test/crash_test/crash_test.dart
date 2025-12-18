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

final _scalarStyles = [
  ScalarStyle.ANY,
  ScalarStyle.PLAIN,
  ScalarStyle.LITERAL,
  ScalarStyle.FOLDED,
  ScalarStyle.SINGLE_QUOTED,
  ScalarStyle.DOUBLE_QUOTED,
];

/// Files with tests that are broken, so we have to skip them
final _skippedFiles = [
  'block_strings.yaml',
  'complex.yaml',
  'explicit_key_value.yaml',
  'mangled_json.yaml',
  'simple_comments.yaml',
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

    for (final (path, node) in _allJsonPaths(root.parseAt([]))) {
      _testJsonPath(fileName, input, path, node);
    }
  }
}

void _testJsonPath(
  String fileName,
  String input,
  Iterable<Object?> path,
  YamlNode node,
) {
  final editorName = 'YamlEditor($fileName)';

  // Try to remove the node
  test('$editorName.remove($path)', () {
    final editor = YamlEditor(input);
    editor.remove(path);
  });

  // Try to update path to a string
  test('$editorName.update($path, \'updated string\')', () {
    final editor = YamlEditor(input);
    editor.update(path, 'updated string');
  });

  // Try to update path to an integer
  test('$editorName.update($path, 42)', () {
    final editor = YamlEditor(input);
    editor.update(path, 42);
  });

  // Try to set a multi-line string for each style
  for (final style in _scalarStyles) {
    test('$editorName.update($path, \'foo\\nbar\') as $style', () {
      final editor = YamlEditor(input);
      editor.update(path, YamlScalar.wrap('foo\nbar', style: style));
    });
  }

  // If it's a list, we try to insert into the list for each index
  if (node is YamlList) {
    for (var i = 0; i < node.length + 1; i++) {
      test('$editorName.insertIntoList($path, $i, 42)', () {
        final editor = YamlEditor(input);
        editor.insertIntoList(path, i, 42);
      });

      test('$editorName.insertIntoList($path, $i, \'new string\')', () {
        final editor = YamlEditor(input);
        editor.insertIntoList(path, i, 'new string');
      });

      for (final style in _scalarStyles) {
        test('$editorName.insertIntoList($path, $i, \'foo\\nbar\') as $style',
            () {
          final editor = YamlEditor(input);
          editor.insertIntoList(
              path,
              i,
              YamlScalar.wrap(
                'foo\nbar',
                style: style,
              ));
        });
      }
    }
  }

  // If it's a map, we try to insert a new key (if the new-key name isn't used)
  if (node is YamlMap && !node.containsKey('new-key')) {
    final newPath = [...path, 'new-key'];

    test('$editorName.update($newPath, 42)', () {
      final editor = YamlEditor(input);
      editor.update(newPath, 42);
    });

    test('$editorName.update($newPath, \'new string\')', () {
      final editor = YamlEditor(input);
      editor.update(newPath, 'new string');
    });

    for (final style in _scalarStyles) {
      test('$editorName.update($newPath, \'foo\\nbar\') as $style', () {
        final editor = YamlEditor(input);
        editor.update(
            newPath,
            YamlScalar.wrap(
              'foo\nbar',
              style: style,
            ));
      });
    }
  }
}

Iterable<(Iterable<Object?>, YamlNode)> _allJsonPaths(
  YamlNode node, [
  Iterable<Object?> parents = const [],
]) sync* {
  yield (parents, node);

  if (node is YamlMap) {
    for (final entry in node.nodes.entries) {
      final key = entry.key as YamlNode;
      final value = entry.value;
      yield* _allJsonPaths(value, [...parents, key.value]);
    }
  } else if (node is YamlList) {
    for (var i = 0; i < node.nodes.length; i++) {
      final value = node.nodes[i];
      yield* _allJsonPaths(value, [...parents, i]);
    }
  }
}
