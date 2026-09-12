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

    group('Law 1 (PutGet / Roundtrip invariant): get(put(d, p, v), p) == v',
        () {
      test('roundtrip on block maps and lists', () {
        final gen = _YamlGenerator(Random(101));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: false,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          editor.update(path, newValue);
          final readBack = editor.parseAt(path);
          expect(deepEquals(readBack, wrapAsYamlNode(newValue)), isTrue,
              reason:
                  'PutGet failed for path $path on block doc:\n${doc.yaml}');

          final reloaded = YamlEditor(editor.toString());
          expect(deepEquals(reloaded.parseAt(path), wrapAsYamlNode(newValue)),
              isTrue,
              reason: 'String roundtrip failed for path $path on:\n'
                  '${editor.toString()}');
        }
      });

      test('roundtrip on flow maps and lists', () {
        final gen = _YamlGenerator(Random(102));
        for (var i = 0; i < 40; i++) {
          final isMap = random.nextBool();
          final doc = gen.generate(
            maxDepth: 2,
            allowFlow: true,
            allowAnchors: false,
            rootKind: isMap ? 'flow_map' : 'flow_list',
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          editor.update(path, newValue);
          final readBack = editor.parseAt(path);
          expect(deepEquals(readBack, wrapAsYamlNode(newValue)), isTrue,
              reason: 'PutGet failed for path $path on flow doc:\n${doc.yaml}');

          final reloaded = YamlEditor(editor.toString());
          expect(deepEquals(reloaded.parseAt(path), wrapAsYamlNode(newValue)),
              isTrue,
              reason: 'String roundtrip failed for flow path $path on:\n'
                  '${editor.toString()}');
        }
      });

      test('roundtrip on mixed nested structures with comments', () {
        final gen = _YamlGenerator(Random(103));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowAnchors: false,
            allowComments: true,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          editor.update(path, newValue);
          final readBack = editor.parseAt(path);
          expect(deepEquals(readBack, wrapAsYamlNode(newValue)), isTrue,
              reason:
                  'PutGet failed for path $path on mixed doc:\n${doc.yaml}');
        }
      });

      test('roundtrip with deeply nested structures', () {
        final gen = _YamlGenerator(Random(104));
        for (var i = 0; i < 30; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: false,
            allowAnchors: false,
            allowComments: false,
          );

          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isNotEmpty) {
            final path = paths[random.nextInt(paths.length)];
            final newValue = _generateRandomValue(random);
            editor.update(path, newValue);
            expect(
              deepEquals(editor.parseAt(path), wrapAsYamlNode(newValue)),
              isTrue,
              reason: 'PutGet failed for path $path',
            );
          }
        }
      });

      test('roundtrip with all scalar types (nulls, booleans, nums, strings)',
          () {
        final gen = _YamlGenerator(Random(105));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(maxDepth: 2, allowAnchors: false);
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];

          // Test null
          editor.update(path, null);
          expect(
              deepEquals(editor.parseAt(path), wrapAsYamlNode(null)), isTrue);

          // Test bool
          final b = random.nextBool();
          editor.update(path, b);
          expect(deepEquals(editor.parseAt(path), wrapAsYamlNode(b)), isTrue);

          // Test int
          final n = random.nextInt(10000) - 5000;
          editor.update(path, n);
          expect(deepEquals(editor.parseAt(path), wrapAsYamlNode(n)), isTrue);

          // Test double
          const d = 3.14159;
          editor.update(path, d);
          expect(deepEquals(editor.parseAt(path), wrapAsYamlNode(d)), isTrue);

          // Test string with special characters
          const s = 'special : # [ ] { } , string';
          editor.update(path, s);
          expect(deepEquals(editor.parseAt(path), wrapAsYamlNode(s)), isTrue);
        }
      });
    });

    group('Law 2 (GetPut / Idempotence): put(d, p, get(d, p)) == d', () {
      test('semantic idempotence on complex generated documents', () {
        final gen = _YamlGenerator(Random(201));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowComments: true,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          final leafPaths =
              paths.where((p) => editor.parseAt(p) is YamlScalar).toList();
          if (leafPaths.isEmpty) continue;

          final path = leafPaths[random.nextInt(leafPaths.length)];
          final current = editor.parseAt(path).value;
          final originalTree = editor.parseAt([]);

          editor.update(path, current);

          expect(deepEquals(editor.parseAt([]), originalTree), isTrue,
              reason: 'GetPut modified semantic tree for path $path on:\n'
                  '${doc.yaml}');
          expect(
              deepEquals(editor.parseAt(path), wrapAsYamlNode(current)), isTrue,
              reason: 'GetPut failed to preserve value at $path');
        }
      });

      test('syntactic idempotence on canonical documents', () {
        final gen = _YamlGenerator(Random(202));
        for (var i = 0; i < 40; i++) {
          final rawDoc = gen.generate(
            maxDepth: 2,
            allowFlow: false,
            allowComments: false,
            allowAnchors: false,
            canonicalScalarsOnly: true,
          );
          final canonicalYaml = YamlEditor(rawDoc.yaml).toString();
          final editor = YamlEditor(canonicalYaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final node = editor.parseAt(path);
          if (node is YamlScalar) {
            editor.update(path, node);
            expect(editor.toString(), equals(canonicalYaml),
                reason: 'GetPut on canonical scalar altered source for path '
                    '$path on:\n$canonicalYaml');
          }
        }
      });

      test('idempotence across all scalar values', () {
        final gen = _YamlGenerator(Random(203));
        for (var i = 0; i < 30; i++) {
          final doc = gen.generate(maxDepth: 2, allowAnchors: false);
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          final scalarPaths =
              paths.where((p) => editor.parseAt(p) is YamlScalar).toList();
          if (scalarPaths.isEmpty) continue;

          final path = scalarPaths[random.nextInt(scalarPaths.length)];
          final currentVal = editor.parseAt(path).value;
          final beforeTree = editor.parseAt([]);

          editor.update(path, currentVal);
          expect(deepEquals(editor.parseAt([]), beforeTree), isTrue);
          expect(editor.parseAt(path).value, equals(currentVal));
        }
      });
    });

    group(
        'Law 3 (PutPut / Sequential Overwrite): '
        'put(put(d, p, v1), p, v2) == put(d, p, v2)', () {
      test('sequential overwrite AST equivalence', () {
        final gen = _YamlGenerator(Random(301));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowComments: true,
            allowAnchors: false,
          );
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final v1 = _generateRandomValue(random);
          final v2 = _generateRandomValue(random);

          editorA.update(path, v1);
          editorA.update(path, v2);

          editorB.update(path, v2);

          expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue,
              reason:
                  'PutPut AST mismatch for path $path on doc:\n${doc.yaml}');
          expect(deepEquals(editorA.parseAt(path), wrapAsYamlNode(v2)), isTrue);
        }
      });

      test('sequential overwrite source representation equivalence on scalars',
          () {
        final gen = _YamlGenerator(Random(302));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 2,
            allowFlow: false,
            allowComments: false,
            allowAnchors: false,
          );
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          final scalarPaths =
              paths.where((p) => editorA.parseAt(p) is YamlScalar).toList();
          if (scalarPaths.isEmpty) continue;

          final path = scalarPaths[random.nextInt(scalarPaths.length)];
          final v1 = 'intermediate_${random.nextInt(1000)}';
          final v2 = 'final_${random.nextInt(1000)}';

          editorA.update(path, v1);
          editorA.update(path, v2);

          editorB.update(path, v2);

          expect(editorA.toString(), equals(editorB.toString()),
              reason: 'PutPut source mismatch for path $path on:\n${doc.yaml}');
        }
      });

      test('sequential overwrite with type transitions (scalar -> map -> list)',
          () {
        final gen = _YamlGenerator(Random(303));
        for (var i = 0; i < 30; i++) {
          final doc = gen.generate(maxDepth: 2, allowAnchors: false);
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];

          editorA.update(path, {'nested': 42});
          editorA.update(path, ['list_a', 'list_b']);
          editorA.update(path, 'final_scalar');

          editorB.update(path, 'final_scalar');

          expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue);
          expect(editorA.parseAt(path).value, equals('final_scalar'));
        }
      });
    });

    group(
        'Law 4 (Disjoint Path Commutativity): '
        'p1 perp p2 => edit(p1) o edit(p2) == edit(p2) o edit(p1)', () {
      test('disjoint paths commute AST equivalence', () {
        final gen = _YamlGenerator(Random(401));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowComments: true,
            allowAnchors: false,
          );
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          final pair = _findDisjointPaths(paths, random);
          if (pair == null) continue;

          final (p1, p2) = pair;
          final v1 = _generateRandomValue(random);
          final v2 = _generateRandomValue(random);

          editorA.update(p1, v1);
          editorA.update(p2, v2);

          editorB.update(p2, v2);
          editorB.update(p1, v1);

          expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue,
              reason: 'Commutativity failed for paths $p1 and $p2 on:\n'
                  '${doc.yaml}');
          expect(deepEquals(editorA.parseAt(p1), wrapAsYamlNode(v1)), isTrue);
          expect(deepEquals(editorA.parseAt(p2), wrapAsYamlNode(v2)), isTrue);
        }
      });

      test('disjoint paths commute source representation equivalence', () {
        final gen = _YamlGenerator(Random(402));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 2,
            allowFlow: false,
            allowComments: false,
            allowAnchors: false,
          );
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          final pair = _findDisjointPaths(paths, random);
          if (pair == null) continue;

          final (p1, p2) = pair;
          final v1 = _generateRandomValue(random);
          final v2 = _generateRandomValue(random);

          editorA.update(p1, v1);
          editorA.update(p2, v2);

          editorB.update(p2, v2);
          editorB.update(p1, v1);

          expect(editorA.toString(), equals(editorB.toString()),
              reason: 'Commutativity source mismatch for $p1 and $p2 on:\n'
                  '${doc.yaml}');
        }
      });

      test('disjoint paths commutativity on non-aliased documents', () {
        final gen = _YamlGenerator(Random(403));
        for (var i = 0; i < 30; i++) {
          final doc = gen.generate(
            maxDepth: 2,
            allowFlow: false,
            allowAnchors: false,
            allowComments: false,
          );
          final editorA = YamlEditor(doc.yaml);
          final editorB = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editorA);
          final pair = _findDisjointPaths(paths, random);
          if (pair == null) continue;

          final (p1, p2) = pair;
          final v1 = _generateRandomValue(random);
          final v2 = _generateRandomValue(random);

          editorA.update(p1, v1);
          editorA.update(p2, v2);

          editorB.update(p2, v2);
          editorB.update(p1, v1);

          expect(deepEquals(editorA.parseAt([]), editorB.parseAt([])), isTrue,
              reason: 'Commutativity failed for paths $p1 and $p2');
        }
      });
    });

    group(
        'Law 5 (Comment & Layout Frame Condition): '
        'comments disjoint from path are preserved', () {
      test('disjoint comments strictly preserved across mutations', () {
        final gen = _YamlGenerator(Random(501));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: false,
            allowComments: true,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          final disjointComments =
              doc.comments.where((c) => _isCommentDisjoint(c, path)).toList();

          editor.update(path, newValue);
          final updatedYaml = editor.toString();

          for (final c in disjointComments) {
            expect(updatedYaml, contains(c.marker),
                reason: 'Disjoint comment "${c.marker}" lost after updating '
                    'path $path on doc:\n${doc.yaml}\nResult:\n$updatedYaml');
          }
        }
      });

      test('full-line header and footer comments frame condition', () {
        final gen = _YamlGenerator(Random(502));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 2,
            allowComments: true,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final headerComments = doc.comments
              .where((c) => c.marker.startsWith('header_comment_'))
              .toList();
          final footerComments = doc.comments
              .where((c) => c.marker.startsWith('footer_comment_'))
              .toList();

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          editor.update(path, newValue);
          final updatedYaml = editor.toString();

          for (final c in headerComments) {
            expect(updatedYaml, contains(c.marker),
                reason: 'Header comment lost after updating $path');
          }
          for (final c in footerComments) {
            expect(updatedYaml, contains(c.marker),
                reason: 'Footer comment lost after updating $path');
          }
        }
      });

      test('sibling layout frame condition (sibling subtrees untouched)', () {
        final gen = _YamlGenerator(Random(503));
        for (var i = 0; i < 40; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowComments: true,
            allowAnchors: false,
          );
          final originalEditor = YamlEditor(doc.yaml);
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          final pair = _findDisjointPaths(paths, random);
          if (pair == null) continue;

          final (updatePath, siblingPath) = pair;
          final siblingBefore = originalEditor.parseAt(siblingPath);
          final newValue = _generateRandomValue(random);

          editor.update(updatePath, newValue);
          final siblingAfter = editor.parseAt(siblingPath);

          expect(deepEquals(siblingAfter, siblingBefore), isTrue,
              reason: 'Sibling subtree at $siblingPath modified when updating '
                  '$updatePath');
        }
      });
    });

    group(
        'Law 6 (2D Indentation Offside Rule): '
        'indentation is monotonically consistent and valid YAML', () {
      test('mutated documents are strictly valid YAML', () {
        final gen = _YamlGenerator(Random(601));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: true,
            allowComments: true,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
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

      test('2D indentation offside rule & monotonicity verified on block docs',
          () {
        final gen = _YamlGenerator(Random(602));
        for (var i = 0; i < 50; i++) {
          final doc = gen.generate(
            maxDepth: 3,
            allowFlow: false,
            allowComments: true,
            allowAnchors: false,
          );
          final editor = YamlEditor(doc.yaml);
          final paths = _collectAllPaths(editor);
          if (paths.isEmpty) continue;

          final path = paths[random.nextInt(paths.length)];
          final newValue = _generateRandomValue(random);

          editor.update(path, newValue);
          final updatedString = editor.toString();

          _assertIndentationOffsideRule(updatedString);
        }
      });
    });
  });
}

class _CommentRecord {
  final String marker;
  final List<Object?> path;
  final bool isInlineValueComment;

  _CommentRecord({
    required this.marker,
    required this.path,
    required this.isInlineValueComment,
  });
}

class _GeneratedDocument {
  final String yaml;
  final List<_CommentRecord> comments;

  _GeneratedDocument({
    required this.yaml,
    required this.comments,
  });
}

class _YamlGenerator {
  final Random r;
  int _anchorCounter = 0;
  int _commentCounter = 0;
  final List<_CommentRecord> _comments = [];

  _YamlGenerator(this.r);

  _GeneratedDocument generate({
    int maxDepth = 3,
    bool allowAnchors = true,
    bool allowFlow = true,
    bool allowComments = true,
    bool canonicalScalarsOnly = false,
    String? rootKind,
  }) {
    _anchorCounter = 0;
    _commentCounter = 0;
    _comments.clear();

    final sb = StringBuffer();

    // Optional header full-line comment
    if (allowComments && r.nextBool()) {
      final id = _commentCounter++;
      final marker = 'header_comment_$id';
      sb.writeln('# $marker');
      _comments.add(_CommentRecord(
        marker: marker,
        path: [],
        isInlineValueComment: false,
      ));
    }

    final kind = rootKind ?? (r.nextBool() ? 'map' : 'list');
    if (kind == 'flow_map') {
      sb.writeln(_generateFlowMap(
        depth: 0,
        maxDepth: maxDepth,
        currentPath: [],
        allowAnchors: allowAnchors,
        allowFlow: allowFlow,
        allowComments: allowComments,
        canonicalScalarsOnly: canonicalScalarsOnly,
      ));
    } else if (kind == 'flow_list') {
      sb.writeln(_generateFlowList(
        depth: 0,
        maxDepth: maxDepth,
        currentPath: [],
        allowAnchors: allowAnchors,
        allowFlow: allowFlow,
        allowComments: allowComments,
        canonicalScalarsOnly: canonicalScalarsOnly,
      ));
    } else if (kind == 'list') {
      _writeBlockList(
        sb,
        depth: 0,
        maxDepth: maxDepth,
        currentPath: [],
        allowAnchors: allowAnchors,
        allowFlow: allowFlow,
        allowComments: allowComments,
        canonicalScalarsOnly: canonicalScalarsOnly,
      );
    } else {
      _writeBlockMap(
        sb,
        depth: 0,
        maxDepth: maxDepth,
        currentPath: [],
        allowAnchors: allowAnchors,
        allowFlow: allowFlow,
        allowComments: allowComments,
        canonicalScalarsOnly: canonicalScalarsOnly,
      );
    }

    // Optional footer comment
    if (allowComments && r.nextBool()) {
      final id = _commentCounter++;
      final marker = 'footer_comment_$id';
      sb.writeln('# $marker');
      _comments.add(_CommentRecord(
        marker: marker,
        path: [],
        isInlineValueComment: false,
      ));
    }

    return _GeneratedDocument(
      yaml: sb.toString(),
      comments: List.unmodifiable(_comments),
    );
  }

  void _writeBlockMap(
    StringBuffer sb, {
    required int depth,
    required int maxDepth,
    required List<Object?> currentPath,
    required bool allowAnchors,
    required bool allowFlow,
    required bool allowComments,
    required bool canonicalScalarsOnly,
  }) {
    final indent = '  ' * depth;
    final numKeys = 2 + r.nextInt(2);
    final localAnchors = <String>[];

    for (var k = 0; k < numKeys; k++) {
      final key = 'key_${depth}_$k';
      final childPath = [...currentPath, key];

      if (allowComments && r.nextBool()) {
        final id = _commentCounter++;
        final marker = 'pre_key_${depth}_${k}_$id';
        sb.writeln('$indent# $marker');
        _comments.add(_CommentRecord(
          marker: marker,
          path: childPath,
          isInlineValueComment: false,
        ));
      }

      if (depth < maxDepth && r.nextInt(3) == 0) {
        final choice = r.nextInt(allowFlow ? 4 : 2);
        if (choice == 0) {
          sb.writeln('$indent$key:');
          _writeBlockMap(
            sb,
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
        } else if (choice == 1) {
          sb.writeln('$indent$key:');
          _writeBlockList(
            sb,
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
        } else if (choice == 2) {
          final flow = _generateFlowMap(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          sb.writeln('$indent$key: $flow');
        } else {
          final flow = _generateFlowList(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          sb.writeln('$indent$key: $flow');
        }
      } else {
        String valStr;
        if (allowAnchors && localAnchors.isNotEmpty && r.nextInt(3) == 0) {
          final a = localAnchors[r.nextInt(localAnchors.length)];
          valStr = '*$a';
        } else if (allowAnchors && k == 0 && r.nextInt(2) == 0) {
          final anc = 'anc_${_anchorCounter++}';
          localAnchors.add(anc);
          valStr = '&$anc ${_generateRawScalar(r, canonicalScalarsOnly)}';
        } else {
          valStr = _generateRawScalar(r, canonicalScalarsOnly);
        }

        if (allowComments && r.nextBool()) {
          final id = _commentCounter++;
          final marker = 'inline_key_${depth}_${k}_$id';
          sb.writeln('$indent$key: $valStr # $marker');
          _comments.add(_CommentRecord(
            marker: marker,
            path: childPath,
            isInlineValueComment: true,
          ));
        } else {
          sb.writeln('$indent$key: $valStr');
        }
      }
    }
  }

  void _writeBlockList(
    StringBuffer sb, {
    required int depth,
    required int maxDepth,
    required List<Object?> currentPath,
    required bool allowAnchors,
    required bool allowFlow,
    required bool allowComments,
    required bool canonicalScalarsOnly,
  }) {
    final indent = '  ' * depth;
    final numItems = 2 + r.nextInt(2);
    final localAnchors = <String>[];

    for (var i = 0; i < numItems; i++) {
      final childPath = [...currentPath, i];

      if (allowComments && r.nextBool()) {
        final id = _commentCounter++;
        final marker = 'pre_item_${depth}_${i}_$id';
        sb.writeln('$indent# $marker');
        _comments.add(_CommentRecord(
          marker: marker,
          path: childPath,
          isInlineValueComment: false,
        ));
      }

      if (depth < maxDepth && r.nextInt(3) == 0) {
        final choice = r.nextInt(allowFlow ? 3 : 1);
        if (choice == 0) {
          final subVal = _generateRawScalar(r, canonicalScalarsOnly);
          sb.writeln('$indent- sub_k: $subVal');
        } else if (choice == 1) {
          final flow = _generateFlowList(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          sb.writeln('$indent- $flow');
        } else {
          final flow = _generateFlowMap(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          sb.writeln('$indent- $flow');
        }
      } else {
        String valStr;
        if (allowAnchors && localAnchors.isNotEmpty && r.nextInt(3) == 0) {
          final a = localAnchors[r.nextInt(localAnchors.length)];
          valStr = '*$a';
        } else if (allowAnchors && i == 0 && r.nextInt(2) == 0) {
          final anc = 'anc_${_anchorCounter++}';
          localAnchors.add(anc);
          valStr = '&$anc ${_generateRawScalar(r, canonicalScalarsOnly)}';
        } else {
          valStr = _generateRawScalar(r, canonicalScalarsOnly);
        }

        if (allowComments && r.nextBool()) {
          final id = _commentCounter++;
          final marker = 'inline_item_${depth}_${i}_$id';
          sb.writeln('$indent- $valStr # $marker');
          _comments.add(_CommentRecord(
            marker: marker,
            path: childPath,
            isInlineValueComment: true,
          ));
        } else {
          sb.writeln('$indent- $valStr');
        }
      }
    }
  }

  String _generateFlowMap({
    required int depth,
    required int maxDepth,
    required List<Object?> currentPath,
    required bool allowAnchors,
    required bool allowFlow,
    required bool allowComments,
    required bool canonicalScalarsOnly,
  }) {
    final entries = <String>[];
    final numKeys = 2 + r.nextInt(2);
    final localAnchors = <String>[];

    for (var k = 0; k < numKeys; k++) {
      final key = 'fk_${depth}_$k';
      final childPath = [...currentPath, key];

      if (depth < maxDepth && allowFlow && r.nextInt(3) == 0) {
        if (r.nextBool()) {
          final inner = _generateFlowList(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          entries.add('$key: $inner');
        } else {
          final inner = _generateFlowMap(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          entries.add('$key: $inner');
        }
      } else {
        String valStr;
        if (allowAnchors && localAnchors.isNotEmpty && r.nextInt(3) == 0) {
          final a = localAnchors[r.nextInt(localAnchors.length)];
          valStr = '*$a';
        } else if (allowAnchors && k == 0 && r.nextInt(2) == 0) {
          final anc = 'anc_${_anchorCounter++}';
          localAnchors.add(anc);
          valStr = '&$anc ${_generateRawScalar(r, canonicalScalarsOnly)}';
        } else {
          valStr = _generateRawScalar(r, canonicalScalarsOnly);
        }
        entries.add('$key: $valStr');
      }
    }

    return '{${entries.join(', ')}}';
  }

  String _generateFlowList({
    required int depth,
    required int maxDepth,
    required List<Object?> currentPath,
    required bool allowAnchors,
    required bool allowFlow,
    required bool allowComments,
    required bool canonicalScalarsOnly,
  }) {
    final items = <String>[];
    final numItems = 2 + r.nextInt(2);
    final localAnchors = <String>[];

    for (var i = 0; i < numItems; i++) {
      final childPath = [...currentPath, i];

      if (depth < maxDepth && allowFlow && r.nextInt(3) == 0) {
        if (r.nextBool()) {
          final inner = _generateFlowList(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          items.add(inner);
        } else {
          final inner = _generateFlowMap(
            depth: depth + 1,
            maxDepth: maxDepth,
            currentPath: childPath,
            allowAnchors: allowAnchors,
            allowFlow: allowFlow,
            allowComments: allowComments,
            canonicalScalarsOnly: canonicalScalarsOnly,
          );
          items.add(inner);
        }
      } else {
        String valStr;
        if (allowAnchors && localAnchors.isNotEmpty && r.nextInt(3) == 0) {
          final a = localAnchors[r.nextInt(localAnchors.length)];
          valStr = '*$a';
        } else if (allowAnchors && i == 0 && r.nextInt(2) == 0) {
          final anc = 'anc_${_anchorCounter++}';
          localAnchors.add(anc);
          valStr = '&$anc ${_generateRawScalar(r, canonicalScalarsOnly)}';
        } else {
          valStr = _generateRawScalar(r, canonicalScalarsOnly);
        }
        items.add(valStr);
      }
    }

    return '[${items.join(', ')}]';
  }
}

String _generateRawScalar(Random r, [bool canonicalOnly = false]) {
  if (canonicalOnly) {
    switch (r.nextInt(4)) {
      case 0:
        return 'null';
      case 1:
        return r.nextBool() ? 'true' : 'false';
      case 2:
        return '${r.nextInt(1000)}';
      default:
        return 'scalar_${r.nextInt(1000)}';
    }
  }

  switch (r.nextInt(5)) {
    case 0:
      const nulls = ['null', '~', 'Null', 'NULL'];
      return nulls[r.nextInt(nulls.length)];
    case 1:
      const bools = ['true', 'false', 'TRUE', 'FALSE'];
      return bools[r.nextInt(bools.length)];
    case 2:
      if (r.nextBool()) {
        final val = r.nextInt(2000) - 1000;
        return '$val';
      } else {
        const doubles = ['0.0', '3.1415', '-0.5', '1.5e2', '-2.718'];
        return doubles[r.nextInt(doubles.length)];
      }
    case 3:
      final type = r.nextInt(4);
      final id = r.nextInt(500);
      switch (type) {
        case 0:
          return 'scalar_$id';
        case 1:
          return "'sq_str_$id'";
        case 2:
          return '"dq_str_$id"';
        default:
          return '"special: # [ ] { } , $id"';
      }
    default:
      return 'val_${r.nextInt(1000)}';
  }
}

Object? _generateRandomValue(Random r) {
  final kind = r.nextInt(8);
  switch (kind) {
    case 0:
      return null;
    case 1:
      return r.nextBool();
    case 2:
      return r.nextBool() ? r.nextInt(10000) : -r.nextInt(1000);
    case 3:
      return (r.nextDouble() * 1000 - 500).roundToDouble() / 10.0;
    case 4:
      const strings = [
        'new_str',
        'hello world',
        'with: colon',
        'with "quotes"',
        'line1\nline2',
      ];
      return '${strings[r.nextInt(strings.length)]}_${r.nextInt(1000)}';
    case 5:
      return [r.nextInt(100), 'val_${r.nextInt(10)}', r.nextBool()];
    case 6:
      return {'k_${r.nextInt(10)}': r.nextInt(100), 'flag': r.nextBool()};
    default:
      final styleRoll = r.nextInt(4);
      if (styleRoll == 0) {
        return wrapAsYamlNode('styled_${r.nextInt(100)}',
            scalarStyle: ScalarStyle.DOUBLE_QUOTED);
      } else if (styleRoll == 1) {
        return wrapAsYamlNode('styled_${r.nextInt(100)}',
            scalarStyle: ScalarStyle.SINGLE_QUOTED);
      } else if (styleRoll == 2) {
        return wrapAsYamlNode([1, 2, 3], collectionStyle: CollectionStyle.FLOW);
      } else {
        return wrapAsYamlNode({'a': 1, 'b': 2},
            collectionStyle: CollectionStyle.BLOCK);
      }
  }
}

List<List<Object?>> _collectAllPaths(YamlEditor editor) {
  final paths = <List<Object?>>[];
  final visited = Set<YamlNode>.identity();

  void walk(List<Object?> path) {
    if (path.length > 8) return;
    final node = editor.parseAt(path);
    if (!visited.add(node)) return;

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
  List<List<Object?>> paths,
  Random r,
) {
  if (paths.length < 2) return null;
  for (var attempt = 0; attempt < 50; attempt++) {
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

bool _isCommentDisjoint(_CommentRecord comment, List<Object?> updatePath) {
  if (updatePath.isEmpty) return false;

  if (comment.isInlineValueComment) {
    return !_isAncestorOrEqual(updatePath, comment.path);
  } else {
    return !_isAncestor(updatePath, comment.path);
  }
}

bool _isAncestorOrEqual(List<Object?> a, List<Object?> b) {
  if (a.length > b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!deepEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _isAncestor(List<Object?> a, List<Object?> b) {
  if (a.length >= b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!deepEquals(a[i], b[i])) return false;
  }
  return true;
}

void _assertIndentationOffsideRule(String yaml) {
  final YamlNode root;
  try {
    root = loadYamlNode(yaml);
  } catch (e) {
    fail('Offside violation: YAML failed to parse:\n$yaml\nError: $e');
  }

  // 1. Verify no tabs used for indentation
  final lines = yaml.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final indentStr = line.substring(0, line.length - trimmed.length);
    expect(indentStr.contains('\t'), isFalse,
        reason: 'Line ${i + 1} contains tab indentation:\n$line');
  }

  // 2. Monotonic indentation on block collections
  void verifyNode(YamlNode node, int minColumn) {
    if (node is YamlMap && node.style == CollectionStyle.BLOCK) {
      int? blockColumn;
      for (final key in node.nodes.keys) {
        if (key is YamlNode) {
          final col = key.span.start.column;
          expect(col >= minColumn, isTrue,
              reason: 'Key at col $col under-indented (min: $minColumn)');
          blockColumn ??= col;
        }
      }
      for (final value in node.nodes.values) {
        verifyNode(value, (blockColumn ?? minColumn) + 1);
      }
    } else if (node is YamlList && node.style == CollectionStyle.BLOCK) {
      for (final item in node.nodes) {
        final col = item.span.start.column;
        expect(col >= minColumn, isTrue,
            reason: 'Item at col $col under-indented (min: $minColumn)');
        verifyNode(item, col);
      }
    }
  }

  verifyNode(root, 0);
}
