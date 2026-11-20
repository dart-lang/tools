// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

import 'yaml_test_suite.dart';

void main() {
  final cases = loadYamlTestSuite().toList();

  for (final c in cases) {
    test(c.name, () {
      if (_expectedFailures.contains(c.id)) {
        try {
          c.runTest();
        } on TestFailure {
          return; // Expected failure, exit the test successfully.
        } catch (e) {
          return; // Other errors from package:yaml are also expected failures.
        }
        fail(
          'Test ${c.id} was expected to fail, but it passed. '
          'Please remove it from _expectedFailures!',
        );
      } else {
        c.runTest();
      }
    });
  }

  test('loadYamlDocumentWithTokens maintains non-overlap and comment oracle',
      () {
    final oldWarn = yamlWarningCallback;
    yamlWarningCallback = (_, [__]) {};
    var parsedCount = 0;
    var commentedCount = 0;
    try {
      for (final c in cases) {
        if (c.fail) continue;
        final ({YamlDocument document, List<YamlToken> tokens}) parsed;
        try {
          parsed = loadYamlDocumentWithTokens(c.yaml);
        } on YamlException {
          // Multi-document or unsupported cases.
          continue;
        }
        final (:tokens, :document) = parsed;
        parsedCount++;
        for (var i = 0; i < tokens.length; i++) {
          expect(tokens[i].span.length, greaterThan(0),
              reason: 'zero-length token in ${c.id}');
          if (i > 0) {
            expect(
              tokens[i].span.start.offset,
              greaterThanOrEqualTo(tokens[i - 1].span.start.offset),
              reason: 'out-of-order tokens in ${c.id}',
            );
            if (tokens[i].span.start.offset < tokens[i - 1].span.end.offset) {
              // Only a header comment inside a non-empty block scalar may
              // overlap the preceding token.
              expect(
                tokens[i].kind,
                YamlTokenKind.comment,
                reason: 'unexpected overlapping token in ${c.id}',
              );
              expect(
                tokens[i - 1].kind,
                YamlTokenKind.scalar,
                reason: 'comment overlaps non-scalar token in ${c.id}',
              );
              expect(
                tokens[i].span.end.offset,
                lessThanOrEqualTo(tokens[i - 1].span.end.offset),
                reason: 'header comment extends past scalar end in ${c.id}',
              );
            }
          }
        }

        // Comment-deletion oracle: removing every retained comment token must
        // stay parsable and preserve the parsed document value (catching
        // false-positive comments inside scalars or syntax).
        final commentTokens = [
          for (final token in tokens)
            if (token.kind == YamlTokenKind.comment) token,
        ];
        if (commentTokens.isNotEmpty) {
          commentedCount++;
          final stripped = _stripComments(c.yaml, commentTokens);
          final YamlDocument reparsed;
          try {
            reparsed = loadYamlDocument(stripped);
          } on YamlException catch (e) {
            fail(
              'stripping comments made ${c.id} unparsable: $e\n$stripped',
            );
          }
          expect(
            _nodesEqual(reparsed.contents, document.contents),
            isTrue,
            reason: 'stripping comments changed value in ${c.id}: '
                'expected ${document.contents.value}, '
                'got ${reparsed.contents.value}',
          );
        }
      }
      expect(parsedCount, greaterThan(200));
      expect(commentedCount, greaterThan(30));
    } finally {
      yamlWarningCallback = oldWarn;
    }
  });
}

String _stripComments(String source, List<YamlToken> comments) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final comment in comments) {
    var start = comment.span.start.offset;
    var end = comment.span.end.offset;

    // If the comment sits on its own line (preceded only by spaces/tabs),
    // drop the full line including its line break so keep-chomped block
    // scalars before it do not absorb a newly created blank line.
    var lineStart = start;
    while (lineStart > 0 &&
        (source.codeUnitAt(lineStart - 1) == 0x20 ||
            source.codeUnitAt(lineStart - 1) == 0x09)) {
      lineStart--;
    }
    final isOwnLine = lineStart == 0 ||
        source.codeUnitAt(lineStart - 1) == 0x0A ||
        source.codeUnitAt(lineStart - 1) == 0x0D;
    if (isOwnLine && lineStart >= cursor) {
      start = lineStart;
      if (end < source.length && source.codeUnitAt(end) == 0x0D) end++;
      if (end < source.length && source.codeUnitAt(end) == 0x0A) end++;
    }

    buffer.write(source.substring(cursor, start));
    cursor = end;
  }
  buffer.write(source.substring(cursor));
  return buffer.toString();
}

bool _nodesEqual(
  YamlNode a,
  YamlNode b, [
  List<(YamlNode, YamlNode)>? visited,
]) {
  final seen = visited ?? <(YamlNode, YamlNode)>[];
  for (final (va, vb) in seen) {
    final loopA = identical(a, va);
    final loopB = identical(b, vb);
    if (loopA && loopB) return true;
    if (loopA || loopB) return false;
  }
  seen.add((a, b));
  try {
    if (a is YamlScalar && b is YamlScalar) {
      final av = a.value;
      final bv = b.value;
      if (av is num && bv is num && av.isNaN && bv.isNaN) return true;
      return av == bv;
    }
    if (a is YamlList && b is YamlList) {
      if (a.nodes.length != b.nodes.length) return false;
      for (var i = 0; i < a.nodes.length; i++) {
        if (!_nodesEqual(a.nodes[i], b.nodes[i], seen)) return false;
      }
      return true;
    }
    if (a is YamlMap && b is YamlMap) {
      if (a.nodes.length != b.nodes.length) return false;
      for (final entry in a.nodes.entries) {
        if (!b.nodes.containsKey(entry.key)) return false;
        if (!_nodesEqual(entry.value, b.nodes[entry.key]!, seen)) return false;
      }
      return true;
    }
    return false;
  } finally {
    seen.removeLast();
  }
}

const _expectedFailures = <String>[
  'VJP3-0',
  '7FWL-0',
  '565N-0',
  '6CK3-0',
  'J7PZ-0',
  'UGM3-0',
  'X4QW-0',
  'CC74-0',
  'CVW2-0',
  'QB6E-0',
  'SU5Z-0',
  'DK4H-0',
  '5TYM-0',
  'Y79Y-0',
  'Y79Y-3',
  'Y79Y-4',
  'Y79Y-5',
  'Y79Y-6',
  'Y79Y-7',
  'Y79Y-8',
  'Y79Y-9',
  '9C9N-0',
  'DK95-0',
  'DK95-1',
  'ZXT5-0',
  'P76L-0',
  '9JBA-0',
  'S98Z-0',
  '2JQS-0',
  'MUS6-0',
  'MUS6-1',
  'BS4K-0',
  'X38W-0',
  'ZYU8-2',
  'RHX7-0',
  '2XXW-0',
  'KS4U-0',
  'Z9M4-0',
  'EB22-0',
  '3HFZ-0',
  // These cases use custom local or %TAG-mapped tags (!foo, !local, !shape,
  // etc.), which Loader intentionally rejects as undefined tags (see
  // yaml_test.dart Examples 2.24, 5.6, 6.18, and 8.21). They previously passed
  // only because Scanner._scanTagUri dropped the scanned tag head and rewrote
  // shorthand '!tag' tokens to the non-specific '!' tag.
  // Note: LHL4-0 ('!invalid{}tag scalar') and 9HCY-0 (missing '...' before
  // '%TAG' after '!foo "bar"') were removed from _expectedFailures for the
  // same reason: their 'fail: true' expectation is now satisfied by Loader
  // rejecting '!invalid' / '!foo', even though the scanner/parser still does
  // not reject the underlying syntax error.
  '6WLZ-0',
  '9WXW-0',
  'C4HZ-0',
  'CUP7-0',
  'M5C3-0',
  'Z67P-0',
];
