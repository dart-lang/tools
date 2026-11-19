// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

import 'yaml_test_suite.dart';

void main() {
  group('loadYamlDocumentWithTokens', () {
    test(
        'emits comments and indicators in ascending start order without '
        '0-length tokens', () {
      const source = '# header\na: [1, 2] # inline\n# footer\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.contents.value, {
        'a': [1, 2]
      });
      expect(tokens.every((t) => t.span.length > 0), isTrue);
      for (var i = 1; i < tokens.length; i++) {
        expect(
          tokens[i].span.start.offset,
          greaterThanOrEqualTo(tokens[i - 1].span.end.offset),
        );
      }
      expect(
        tokens
            .where((t) => t.kind == YamlTokenKind.comment)
            .map((t) => t.span.text),
        ['# header', '# inline', '# footer'],
      );
      expect(() => tokens.add(tokens.first), throwsUnsupportedError);
    });

    test('retains comments in empty or comment-only documents', () {
      const source = '# first\n# second\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.contents.value, isNull);
      expect(
        tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.comment, '# first'),
          (YamlTokenKind.comment, '# second'),
        ],
      );
    });

    test('retains comments outside document.span', () {
      const source = '# lead\n---\na: 1\n...\n# trail\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.contents.value, {'a': 1});
      expect(
        tokens
            .where((t) => t.kind == YamlTokenKind.comment)
            .map((t) => t.span.text),
        ['# lead', '# trail'],
      );
    });

    test('emits all token kinds accurately', () {
      const source = '%YAML 1.2\n'
          '%TAG !e! tag:yaml.org,2002:\n'
          '---\n'
          '# comment\n'
          '? &anc !e!str "val"\n'
          ':\n'
          '  - [*anc, {k: 1}]\n'
          '...\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.versionDirective.toString(), '%YAML 1.2');
      expect(
        tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.versionDirective, '%YAML 1.2'),
          (YamlTokenKind.tagDirective, '%TAG !e! tag:yaml.org,2002:'),
          (YamlTokenKind.documentStart, '---'),
          (YamlTokenKind.comment, '# comment'),
          (YamlTokenKind.key, '?'),
          (YamlTokenKind.anchor, '&anc'),
          (YamlTokenKind.tag, '!e!str'),
          (YamlTokenKind.scalar, '"val"'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.blockEntry, '-'),
          (YamlTokenKind.flowSequenceStart, '['),
          (YamlTokenKind.alias, '*anc'),
          (YamlTokenKind.flowEntry, ','),
          (YamlTokenKind.flowMappingStart, '{'),
          (YamlTokenKind.scalar, 'k'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, '1'),
          (YamlTokenKind.flowMappingEnd, '}'),
          (YamlTokenKind.flowSequenceEnd, ']'),
          (YamlTokenKind.documentEnd, '...'),
        ],
      );
    });

    test('retains value token for empty implicit flow key', () {
      final (:document, :tokens) = loadYamlDocumentWithTokens('{: a}');
      expect(document.contents.value, {null: 'a'});
      expect(
        tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.flowMappingStart, '{'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, 'a'),
          (YamlTokenKind.flowMappingEnd, '}'),
        ],
      );
    });

    test('does not overlap empty block scalar and header comment', () {
      const source = 'a: > # comment\n\nb: 1\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.contents.value, {'a': '', 'b': 1});
      for (var i = 1; i < tokens.length; i++) {
        expect(
          tokens[i].span.start.offset,
          greaterThanOrEqualTo(tokens[i - 1].span.end.offset),
        );
      }
      expect(
        tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.scalar, 'a'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, '>'),
          (YamlTokenKind.comment, '# comment'),
          (YamlTokenKind.scalar, 'b'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, '1'),
        ],
      );
    });

    test('orders non-empty block scalar before its overlapping header comment',
        () {
      const source = 'a: | # hdr\n  hello\n';
      final (:document, :tokens) = loadYamlDocumentWithTokens(source);
      expect(document.contents.value, {'a': 'hello\n'});
      final scalar = tokens.firstWhere(
          (t) => t.kind == YamlTokenKind.scalar && t.span.start.offset > 0);
      final comment = tokens.firstWhere((t) => t.kind == YamlTokenKind.comment);
      expect(scalar.span.text, '| # hdr\n  hello');
      expect(comment.span.text, '# hdr');
      expect(tokens.indexOf(scalar), lessThan(tokens.indexOf(comment)));
      expect(scalar.span.start.offset, lessThan(comment.span.start.offset));
      expect(comment.span.end.offset, lessThan(scalar.span.end.offset));
    });

    test('retains unknown directives and their trailing comments', () {
      const source = '%FOO bar # trailing\n---\na: 1\n';
      final warnings = <String>[];
      final oldWarn = yamlWarningCallback;
      yamlWarningCallback = (msg, [span]) => warnings.add(msg);
      try {
        final (:document, :tokens) = loadYamlDocumentWithTokens(source);
        expect(document.contents.value, {'a': 1});
        expect(warnings, hasLength(1));
        expect(
          tokens.map((t) => (t.kind, t.span.text)).toList(),
          [
            (YamlTokenKind.unknownDirective, '%FOO bar'),
            (YamlTokenKind.comment, '# trailing'),
            (YamlTokenKind.documentStart, '---'),
            (YamlTokenKind.scalar, 'a'),
            (YamlTokenKind.value, ':'),
            (YamlTokenKind.scalar, '1'),
          ],
        );
      } finally {
        yamlWarningCallback = oldWarn;
      }
    });

    test('throws on multiple documents', () {
      expect(
        () => loadYamlDocumentWithTokens('---\na: 1\n---\nb: 2\n'),
        throwsA(isA<YamlException>()),
      );
    });

    test('maintains ascending start order across yaml-test-suite', () {
      final oldWarn = yamlWarningCallback;
      yamlWarningCallback = (_, [__]) {};
      try {
        for (final c in loadYamlTestSuite()) {
          if (c.fail) continue;
          try {
            final (:tokens, document: _) = loadYamlDocumentWithTokens(c.yaml);
            for (var i = 0; i < tokens.length; i++) {
              expect(tokens[i].span.length, greaterThan(0),
                  reason: 'zero-length token in ${c.id}');
              if (i > 0) {
                expect(
                  tokens[i].span.start.offset,
                  greaterThanOrEqualTo(tokens[i - 1].span.start.offset),
                  reason: 'out-of-order tokens in ${c.id}',
                );
              }
            }
          } on YamlException {
            // Multi-document or unsupported cases.
          }
        }
      } finally {
        yamlWarningCallback = oldWarn;
      }
    });
  });
}
