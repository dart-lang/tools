// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

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

        // Unknown directive without explicit `---` still parses identically to
        // previous releases (line break is left for `_scanToNextToken`).
        expect(loadYaml('%FOO bar # c\na: 1\n'), {'a': 1});
        expect(loadYaml('%FOO\n- a\n'), ['a']);
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

    test('supports recover: true with errorListener', () {
      final collector = ErrorCollector();
      final (:document, :tokens) = loadYamlDocumentWithTokens(
        'a: 1\nb\n',
        recover: true,
        errorListener: collector,
      );
      expect(collector.errors, hasLength(1));
      expect(collector.errors.first.message, contains("Expected ':'"));
      expect(document.contents.value, {'a': 1, 'b': null});
      expect(tokens.every((t) => t.span.length > 0), isTrue);
      expect(
        tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.scalar, 'a'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, '1'),
          (YamlTokenKind.scalar, 'b'),
        ],
      );
    });

    test('rejects errorListener when recover is false', () {
      expect(
        () => loadYamlDocumentWithTokens(
          'a: 1\n',
          errorListener: ErrorCollector(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('propagates sourceUrl to document and token spans', () {
      final url = Uri.parse('package:example/config.yaml');
      final (:document, :tokens) =
          loadYamlDocumentWithTokens('a: 1 # note\n', sourceUrl: url);
      expect(document.span.sourceUrl, url);
      expect(tokens, isNotEmpty);
      expect(tokens.every((t) => t.span.sourceUrl == url), isTrue);
    });

    test('handles BOM, CRLF, tabs before comments, and EOF comments', () {
      final bomResult = loadYamlDocumentWithTokens('\uFEFFa: 1 # bom\n');
      expect(bomResult.document.contents.value, {'a': 1});
      expect(
        bomResult.tokens.map((t) => (t.kind, t.span.text)).toList(),
        [
          (YamlTokenKind.scalar, 'a'),
          (YamlTokenKind.value, ':'),
          (YamlTokenKind.scalar, '1'),
          (YamlTokenKind.comment, '# bom'),
        ],
      );

      const crlfAndTabs = 'a: 1\t# c1\r\nb: [2, # c2\r\n  3]\r\n... # end';
      final (:document, :tokens) = loadYamlDocumentWithTokens(crlfAndTabs);
      expect(document.contents.value, {
        'a': 1,
        'b': [2, 3],
      });
      expect(
        tokens
            .where((t) => t.kind == YamlTokenKind.comment)
            .map((t) => t.span.text),
        ['# c1', '# c2', '# end'],
      );
      expect(tokens.last.kind, YamlTokenKind.comment);
      expect(tokens.last.span.end.offset, crlfAndTabs.length);
    });

    test('formats toString on YamlToken and YamlTokenKind', () {
      final (:tokens, document: _) = loadYamlDocumentWithTokens('a: 1\n');
      expect(tokens.first.toString(), 'scalar(0..1)');
      expect(tokens.first.kind.toString(), 'YamlTokenKind.scalar');
    });
  });
}
