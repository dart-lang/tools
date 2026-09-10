// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('Formal Algebraic Laws (Property-Based Fuzzing)', () {
    final random = Random(42);

    test('Law 1: PutGet / Roundtrip invariant', () {
      for (var i = 0; i < 50; i++) {
        final doc = _generateRandomYaml(random, maxDepth: 3);
        final editor = YamlEditor(doc);
        final paths = _collectAllPaths(editor);
        if (paths.isEmpty) continue;

        final path = paths[random.nextInt(paths.length)];
        final newValue = _generateRandomValue(random);

        editor.update(path, newValue);
        final readBack = editor.parseAt(path);
        expect(deepEquals(readBack, wrapAsYamlNode(newValue)), isTrue,
            reason: 'PutGet failed for path $path on doc:\n$doc');
      }
    });

    test('Law 2: GetPut / Idempotence invariant', () {
      for (var i = 0; i < 50; i++) {
        final doc = _generateRandomYaml(random, maxDepth: 3);
        final editor = YamlEditor(doc);
        final paths = _collectAllPaths(editor);
        if (paths.isEmpty) continue;

        final path = paths[random.nextInt(paths.length)];
        final current = editor.parseAt(path).value;

        editor.update(path, current);
        final readBack = editor.parseAt(path);
        expect(deepEquals(readBack, wrapAsYamlNode(current)), isTrue,
            reason: 'GetPut failed for path $path on doc:\n$doc');
      }
    });

    test('Law 3: PutPut / Sequential Overwrite invariant', () {
      for (var i = 0; i < 50; i++) {
        final doc = _generateRandomYaml(random, maxDepth: 3);
        final editorA = YamlEditor(doc);
        final editorB = YamlEditor(doc);
        final paths = _collectAllPaths(editorA);
        if (paths.isEmpty) continue;

        final path = paths[random.nextInt(paths.length)];
        final v1 = _generateRandomValue(random);
        final v2 = _generateRandomValue(random);

        editorA.update(path, v1);
        editorA.update(path, v2);

        editorB.update(path, v2);

        expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue,
            reason: 'PutPut failed for path $path on doc:\n$doc');
      }
    });

    test('Law 4: Disjoint Path Commutativity invariant', () {
      for (var i = 0; i < 50; i++) {
        final doc = _generateRandomYaml(random, maxDepth: 3);
        final editorA = YamlEditor(doc);
        final editorB = YamlEditor(doc);
        final disjointPair = _findDisjointPaths(editorA, random);
        if (disjointPair == null) continue;

        final (p1, p2) = disjointPair;
        final v1 = _generateRandomValue(random);
        final v2 = _generateRandomValue(random);

        editorA.update(p1, v1);
        editorA.update(p2, v2);

        editorB.update(p2, v2);
        editorB.update(p1, v1);

        expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue,
            reason: 'Commutativity failed for paths $p1 and $p2 on:\n$doc');
      }
    });

    test('Law 5: Comment & Layout Conservation (Frame condition)', () {
      for (var i = 0; i < 50; i++) {
        final marker = '# preserved_comment_id_$i';
        final doc = '''
# Top header
keyA: valueA  $marker
keyB:
  nested1: 100
  nested2: 200 # inner comment
keyC:
  - item1
  - item2
''';
        final editor = YamlEditor(doc);
        final paths = [
          ['keyB', 'nested1'],
          ['keyB', 'nested2'],
          ['keyC', 0],
          ['keyC', 1],
        ];

        final path = paths[random.nextInt(paths.length)];
        final newValue = _generateRandomValue(random);

        editor.update(path, newValue);
        expect(editor.toString(), contains(marker),
            reason: 'Marker comment lost after updating $path');
      }
    });

    test('Law 6: 2D Indentation Offside Rule & Well-Formedness', () {
      for (var i = 0; i < 50; i++) {
        final doc = _generateRandomYaml(random, maxDepth: 3);
        final editor = YamlEditor(doc);
        final paths = _collectAllPaths(editor);
        if (paths.isEmpty) continue;

        final path = paths[random.nextInt(paths.length)];
        final newValue = _generateRandomValue(random);

        editor.update(path, newValue);
        final updatedString = editor.toString();

        expect(() => loadYaml(updatedString), returnsNormally,
            reason: 'Updated string failed to parse:\n$updatedString');
      }
    });
  });
}

String _generateRandomYaml(Random r, {int maxDepth = 3}) {
  final sb = StringBuffer();
  _writeBlockMap(sb, r, depth: 0, maxDepth: maxDepth);
  return sb.toString();
}

void _writeBlockMap(StringBuffer sb, Random r,
    {required int depth, required int maxDepth}) {
  final indent = '  ' * depth;
  final numKeys = 2 + r.nextInt(3);
  for (var k = 0; k < numKeys; k++) {
    final key = 'key_${depth}_$k';
    if (r.nextBool()) {
      sb.writeln('$indent# Comment before $key');
    }
    if (depth < maxDepth && r.nextInt(3) == 0) {
      sb.writeln('$indent$key:');
      if (r.nextBool()) {
        _writeBlockList(sb, r, depth: depth + 1, maxDepth: maxDepth);
      } else {
        _writeBlockMap(sb, r, depth: depth + 1, maxDepth: maxDepth);
      }
    } else {
      final val = _generateScalarYaml(r);
      if (r.nextBool()) {
        sb.writeln('$indent$key: $val # Same-line comment');
      } else {
        sb.writeln('$indent$key: $val');
      }
    }
  }
}

void _writeBlockList(StringBuffer sb, Random r,
    {required int depth, required int maxDepth}) {
  final indent = '  ' * depth;
  final numItems = 2 + r.nextInt(3);
  for (var i = 0; i < numItems; i++) {
    if (r.nextBool()) {
      sb.writeln('$indent# Comment before item $i');
    }
    if (depth < maxDepth && r.nextInt(3) == 0) {
      sb.writeln('$indent- key_sub: ${r.nextInt(100)}');
    } else {
      final val = _generateScalarYaml(r);
      sb.writeln('$indent- $val');
    }
  }
}

String _generateScalarYaml(Random r) {
  switch (r.nextInt(5)) {
    case 0:
      return '${r.nextInt(1000)}';
    case 1:
      return r.nextBool() ? 'true' : 'false';
    case 2:
      return '"str_${r.nextInt(500)}"';
    case 3:
      return "'str_${r.nextInt(500)}'";
    default:
      return 'scalar_${r.nextInt(500)}';
  }
}

Object? _generateRandomValue(Random r) {
  switch (r.nextInt(5)) {
    case 0:
      return r.nextInt(10000);
    case 1:
      return r.nextBool();
    case 2:
      return 'new_str_${r.nextInt(1000)}';
    case 3:
      return [r.nextInt(10), 'val_${r.nextInt(10)}'];
    default:
      return {'k_${r.nextInt(10)}': r.nextInt(100)};
  }
}

List<List<Object?>> _collectAllPaths(YamlEditor editor) {
  final paths = <List<Object?>>[];
  void walk(List<Object?> path) {
    final node = editor.parseAt(path);
    if (node is YamlMap) {
      for (final key in node.keys) {
        final subPath = [...path, key];
        paths.add(subPath);
        walk(subPath);
      }
    } else if (node is YamlList) {
      for (var i = 0; i < node.length; i++) {
        final subPath = [...path, i];
        paths.add(subPath);
        walk(subPath);
      }
    }
  }

  walk([]);
  return paths;
}

(List<Object?>, List<Object?>)? _findDisjointPaths(
    YamlEditor editor, Random r) {
  final paths = _collectAllPaths(editor);
  if (paths.length < 2) return null;

  for (var attempt = 0; attempt < 20; attempt++) {
    final p1 = paths[r.nextInt(paths.length)];
    final p2 = paths[r.nextInt(paths.length)];
    if (_areDisjoint(p1, p2)) {
      return (p1, p2);
    }
  }
  return null;
}

bool _areDisjoint(List<Object?> p1, List<Object?> p2) {
  if (p1.isEmpty || p2.isEmpty) return false;
  final minLen = min(p1.length, p2.length);
  for (var i = 0; i < minLen; i++) {
    if (!deepEquals(p1[i], p2[i])) return true;
  }
  return false;
}
