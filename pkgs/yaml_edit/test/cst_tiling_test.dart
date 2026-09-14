// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Checks the invariant the CST rests on: that it tiles its source exactly.
///
/// [CstDocument.parse] enforces the invariant itself and throws when it cannot
/// hold, so these tests are really a measure of *coverage* — how much of real
/// YAML the model can represent — rather than of correctness. A document that
/// throws here is one the editor will refuse to touch.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';

/// Parses [source] and asserts the CST reproduces it exactly.
void checkTiles(String source) {
  final document = CstDocument.parse(source);
  expect(render(document), source,
      reason: 'the CST did not reproduce its source');
}

/// Reconstructs the source by walking the CST's slots in order.
///
/// This duplicates what the tiling check already guarantees, but does it by a
/// different route — concatenating substrings rather than checking boundaries —
/// so a mistake in one is unlikely to be mirrored in the other.
String render(CstDocument document) {
  final source = document.source;
  final buffer = StringBuffer();
  var cursor = 0;

  void upTo(int offset) {
    buffer.write(source.substring(cursor, offset));
    cursor = offset;
  }

  void visitNode(CstNode node) {
    upTo(node.start);
    upTo(node.contentStart);
    switch (node) {
      case CstScalar():
      case CstAlias():
      case CstEmpty():
        upTo(node.end);
      case CstBlockSeq():
        for (final entry in node.entries) {
          upTo(entry.dashStart + 1);
          visitNode(entry.value);
          upTo(entry.end);
        }
      case CstBlockMap():
        for (final entry in node.entries) {
          if (entry.questionMark case final questionMark?) {
            upTo(questionMark + 1);
          }
          visitNode(entry.key);
          if (entry.colon case final colon?) upTo(colon + 1);
          visitNode(entry.value);
          upTo(entry.end);
        }
      case CstFlowPair():
        if (node.questionMark case final questionMark?) {
          upTo(questionMark + 1);
        }
        visitNode(node.key);
        if (node.colon case final colon?) upTo(colon + 1);
        visitNode(node.pairValue);
      case CstFlowCollection():
        upTo(node.openEnd);
        for (final entry in node.entries) {
          if (entry.questionMark case final questionMark?) {
            upTo(questionMark + 1);
          }
          if (entry.key case final key?) {
            visitNode(key);
            if (entry.colon case final colon?) upTo(colon + 1);
          }
          visitNode(entry.value);
          if (entry.comma case final comma?) upTo(comma + 1);
          upTo(entry.end);
        }
        upTo(node.end);
    }
  }

  if (document.root case final root?) visitNode(root);
  upTo(source.length);
  return buffer.toString();
}

void main() {
  group('tiles hand-written documents', () {
    const cases = <String, String>{
      'empty': '',
      'blank': '\n\n',
      'comment only': '# hello\n',
      'block map': 'a: 1\nb: 2\n',
      'block map without trailing newline': 'a: 1\nb: 2',
      'block map with comments': 'a: 1 # one\n# about b\nb: 2\n',
      'block seq': '- 1\n- 2\n',
      'block seq with comments': '- 1 # one\n# about two\n- 2\n',
      'nested block': 'a:\n  b:\n    c: 1\n',
      'zero indent seq': 'key:\n- 1\n- 2\n',
      'nested seq': '- - 1\n  - 2\n',
      'compact map in seq': '- a: 1\n  b: 2\n',
      'flow seq': '[1, 2]',
      'flow seq trailing comma': '[1, 2, ]',
      'flow seq multiline': '[\n  1,\n  2,\n]',
      'flow map': '{a: 1, b: 2}',
      'empty flow seq': '[]',
      'empty flow map': '{ }',
      'flow map null values': '{a, b}',
      'nested flow': '{a: {b: [1, 2]}}',
      'single pair flow map in seq': '[a: 1]',
      'empty value': 'a:\nb: 2\n',
      'empty seq entry': '-\n- 2\n',
      'empty seq entry with space': '- \n- 2\n',
      'explicit key': '? complex\n: value\n',
      'explicit key no value': '? a\n? b\n',
      'literal scalar': 'a: |\n  block\n  scalar\n',
      'folded scalar': 'a: >\n  folded\n',
      'literal keep': 'a: |+\n  keep\n\n',
      'literal with indent indicator': 'a: |2\n    x\nb: 2\n',
      'quoted': "a: 'single'\nb: \"double\"\n",
      'multiline plain in map': 'a: plain\n  multi\nb: 2\n',
      'multiline plain in seq': '- plain\n  multi\n- 2\n',
      'multiline plain at root': 'plain multi\n  line\n',
      'plain at root': 'plain\n',
      'document markers': '---\na: 1\n...\n',
      'directive': '%YAML 1.2\n---\na: 1\n',
      'bare document marker': '--- a\n',
      'tagged root': '--- !!str a\n',
      'tag on scalar': '- !!str x\n- 2\n',
      'tag on flow map': '- !custom {a: 1}\n',
      'tag on block map': 'a: !!map\n  b: 1\n',
      'anchor on scalar': 'a: &x 1\nb: 2\n',
      'anchor on flow seq': '- &x [1, 2]\n- 2\n',
      'anchor on block seq': '- &x\n  - 1\n- 2\n',
      'anchor on block map': 'a: &anchor\n  b: 1\nc: 2\n',
      'alias': 'a: &x 1\nb: *x\nc: 3\n',
      'alias in flow': '[&x 1, *x]',
      'alias in nested seq': 'a: &x 1\nb:\n  - *x\n  - 2\n',
      'trailing comment': 'a: 1\n\n\n# trailing\n',
      'unterminated trailing comment': 'a: 1\n#end',
      'crlf': 'a: 1\r\nb: 2\r\n',
      'tab indented document': '\ta: 1\n',
      'tab after colon': 'a:\t1\n',
      'extra spaces': 'a:  1   \nb:\t2\n',
      'comment after colon': 'a: # comment\n  b: 1\n',
      'comment after dash': '- # comment\n  1\n',
      'comment before nested map': 'a:\n  # comment\n  b: 1\n',
      'blank line inside map': 'a:\n\n  b: 1\n',
      'quoted key with newline': '"a\\nb": 1\n',
      'key with spaces': 'key with spaces: value\n',
      'empty string values': 'a: ""\nb: \'\'\n',
      'null values': 'a: null\nb: ~\n',
      'multiline flow in block': 'a: [1,\n    2]\n',
    };

    cases.forEach((name, source) {
      test(name, () => checkTiles(source));
    });
  });

  group('yaml-test-suite', () {
    late final Directory suite;

    setUpAll(() async {
      final packageUri = await Isolate.resolvePackageUri(
          Uri.parse('package:yaml_edit/yaml_edit.dart'));
      suite = Directory.fromUri(
          packageUri!.resolve('../../../third_party/yaml-test-suite/src/'));
    });

    test('every document the parser accepts is tiled exactly', () {
      if (!suite.existsSync()) {
        markTestSkipped('yaml-test-suite not available at ${suite.path}');
        return;
      }

      var accepted = 0;
      final failures = <String, Object>{};

      for (final file in suite.listSync().whereType<File>()) {
        if (!file.path.endsWith('.yaml')) continue;
        final cases = loadYaml(file.readAsStringSync());
        if (cases is! YamlList) continue;
        final basename = file.uri.pathSegments.last.replaceAll('.yaml', '');

        for (final (index, testCase) in cases.indexed) {
          if (testCase is! YamlMap) continue;
          if (testCase.containsKey('error') || testCase.containsKey('fail')) {
            continue;
          }
          final source = testCase['yaml'];
          if (source is! String) continue;

          // Only documents our own parser accepts are in scope.
          try {
            loadYamlNode(source);
          } catch (_) {
            continue;
          }

          accepted++;
          try {
            checkTiles(source);
          } catch (error) {
            failures['${basename}_$index'] = error;
          }
        }
      }

      expect(accepted, greaterThan(100),
          reason: 'expected a meaningful number of cases to be in scope');
      final failureList = failures.entries
          .take(20)
          .map((e) => '  ${e.key}: ${e.value}')
          .join('\n');
      expect(failures, isEmpty,
          reason: '${failures.length} of $accepted documents were not tiled:\n'
              '$failureList');
    });
  });
}
