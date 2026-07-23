// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

final scalarStyles = [
  ScalarStyle.ANY,
  ScalarStyle.PLAIN,
  ScalarStyle.LITERAL,
  ScalarStyle.FOLDED,
  ScalarStyle.SINGLE_QUOTED,
  ScalarStyle.DOUBLE_QUOTED,
];

void _tryMutate(void Function() mutate) {
  try {
    withYamlWarningCallback(mutate);
  } on AliasException {
    // AliasException is thrown when a mutation is not valid due to aliases.
    // We ignore this exception as it is expected behavior.
  }
}

void testJsonPath(
  String fileName,
  String input,
  Iterable<Object?> path,
  YamlNode node,
) {
  final editorName = 'YamlEditor($fileName)';

  // Try to remove the node
  test('$editorName.remove($path)', () {
    _tryMutate(() {
      final editor = YamlEditor(input);
      editor.remove(path);
    });
  });

  // Try to update path to a string
  test('$editorName.update($path, \'updated string\')', () {
    _tryMutate(() {
      final editor = YamlEditor(input);
      editor.update(path, 'updated string');
    });
  });

  // Try to update path to an integer
  test('$editorName.update($path, 42)', () {
    _tryMutate(() {
      final editor = YamlEditor(input);
      editor.update(path, 42);
    });
  });

  // Try to set a multi-line string for each style
  for (final style in scalarStyles) {
    test('$editorName.update($path, \'foo\\nbar\') as $style', () {
      _tryMutate(() {
        final editor = YamlEditor(input);
        editor.update(path, YamlScalar.wrap('foo\nbar', style: style));
      });
    });
  }

  // If it's a list, we try to insert into the list for each index
  if (node is YamlList) {
    for (var i = 0; i < node.length + 1; i++) {
      test('$editorName.insertIntoList($path, $i, 42)', () {
        _tryMutate(() {
          final editor = YamlEditor(input);
          editor.insertIntoList(path, i, 42);
        });
      });

      test('$editorName.insertIntoList($path, $i, \'new string\')', () {
        _tryMutate(() {
          final editor = YamlEditor(input);
          editor.insertIntoList(path, i, 'new string');
        });
      });

      for (final style in scalarStyles) {
        test('$editorName.insertIntoList($path, $i, \'foo\\nbar\') as $style',
            () {
          _tryMutate(() {
            final editor = YamlEditor(input);
            editor.insertIntoList(
                path,
                i,
                YamlScalar.wrap(
                  'foo\nbar',
                  style: style,
                ));
          });
        });
      }
    }
  }

  // If it's a map, we try to insert a new key (if the new-key name isn't used)
  if (node is YamlMap && !node.containsKey('new-key')) {
    final newPath = [...path, 'new-key'];

    test('$editorName.update($newPath, 42)', () {
      _tryMutate(() {
        final editor = YamlEditor(input);
        editor.update(newPath, 42);
      });
    });

    test('$editorName.update($newPath, \'new string\')', () {
      _tryMutate(() {
        final editor = YamlEditor(input);
        editor.update(newPath, 'new string');
      });
    });

    for (final style in scalarStyles) {
      test('$editorName.update($newPath, \'foo\\nbar\') as $style', () {
        _tryMutate(() {
          final editor = YamlEditor(input);
          editor.update(
              newPath,
              YamlScalar.wrap(
                'foo\nbar',
                style: style,
              ));
        });
      });
    }
  }
}

Iterable<(Iterable<Object?>, YamlNode)> allJsonPaths(
  YamlNode node, [
  Iterable<Object?> parents = const [],
]) sync* {
  yield (parents, node);

  if (node is YamlMap) {
    for (final entry in node.nodes.entries) {
      final key = entry.key as YamlNode;
      final value = entry.value;
      yield* allJsonPaths(value, [...parents, key.value]);
    }
  } else if (node is YamlList) {
    for (var i = 0; i < node.nodes.length; i++) {
      final value = node.nodes[i];
      yield* allJsonPaths(value, [...parents, i]);
    }
  }
}
