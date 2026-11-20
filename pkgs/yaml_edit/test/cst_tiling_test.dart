// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/utils.dart' show withYamlWarningCallback;

/// Renders the structural shape of [node] with exact `[start..end)` offsets
/// for golden assertions.
String dumpNode(CstNode node, String source) {
  String slice(int start, int end) => source
      .substring(start, end)
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');

  final props =
      node.hasProperties ? 'props=[${node.start}..${node.contentStart}) ' : '';
  return switch (node) {
    CstScalar() => 'Scalar($props[${node.contentStart}..${node.end}) '
        '"${slice(node.contentStart, node.end)}")',
    CstAlias() =>
      'Alias([${node.start}..${node.end}) "${slice(node.start, node.end)}")',
    CstEmpty() => 'Empty(@${node.start})',
    CstBlockSeq() => 'BlockSeq($props${node.isCompact ? 'compact ' : ''}'
        '[${node.entries.map((e) => 'Entry(line=${e.lineStart} '
            'dash=${e.dashStart} ${dumpNode(e.value, source)})').join(', ')}])',
    CstBlockMap() => 'BlockMap($props${node.isCompact ? 'compact ' : ''}'
        '{${node.entries.map((e) => 'Entry(line=${e.lineStart}'
            '${e.questionMark != null ? ' ?=${e.questionMark}' : ''} '
            'key=${dumpNode(e.key, source)}'
            '${e.colon != null ? ' :=${e.colon}' : ''} '
            'val=${dumpNode(e.value, source)})').join(', ')}})',
    CstFlowSeq() => 'FlowSeq($props'
        '[${node.entries.map((e) => dumpNode(e.value, source)).join(', ')}])',
    CstFlowMap() => 'FlowMap($props'
        '{${node.entries.map((e) => '${dumpNode(e.key!, source)}: '
            '${dumpNode(e.value, source)}').join(', ')}})',
    CstFlowPair() => 'FlowPair($props${dumpNode(node.key, source)}: '
        '${dumpNode(node.pairValue, source)})',
  };
}

/// Replaces special characters used by yaml-test-suite to visualize invisible
/// characters.
/// See: https://github.com/yaml/yaml-test-suite/blob/main/ReadMe.md#special-characters
String _replaceSpecialCharacters(String input) => input
    .replaceAll('␣', ' ')
    .replaceAll(RegExp(r'—*»'), '\t')
    .replaceAll('↵', '')
    .replaceAll('←', '\r')
    .replaceAll('⇔', '\uFEFF')
    .replaceFirst(RegExp(r'∎\n?$'), '');

void main() {
  group('structural CST parsing', () {
    test('compact map whose first key is an alias', () {
      const source = '- &a k\n- *a : v\n';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstBlockSeq;
      expect(root.entries, hasLength(2));
      final second = root.entries[1].value as CstBlockMap;
      expect(second.isCompact, isTrue);
      expect(second.entries, hasLength(1));
      final entry = second.entries.single;
      expect(entry.key, isA<CstAlias>());
      expect(source.substring(entry.key.start, entry.key.end), '*a');
      expect(entry.colon, 12);
      expect(entry.value, isA<CstScalar>());
      expect(entry.value.value.value, 'v');
    });

    test('single flow pair with braced map key and value', () {
      const source = '[{a: 1}: {b: 2}]';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstFlowSeq;
      final pair = root.entries.single.value as CstFlowPair;
      expect(pair.hasProperties, isFalse);
      expect(pair.key, isA<CstFlowMap>());
      expect(source.substring(pair.key.start, pair.key.end), '{a: 1}');
      expect(pair.colon, 7);
      expect(pair.pairValue, isA<CstFlowMap>());
      expect(
          source.substring(pair.pairValue.start, pair.pairValue.end), '{b: 2}');
    });

    test('explicit key does not steal parent mapping colon', () {
      const source = 'a:\n  ? b\n: c\n';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstBlockMap;
      expect(root.entries, hasLength(2));

      final innerMap = root.entries[0].value as CstBlockMap;
      expect(innerMap.entries, hasLength(1));
      expect(innerMap.entries.single.questionMark, 5);
      expect(innerMap.entries.single.colon, isNull);
      expect(innerMap.entries.single.value, isA<CstEmpty>());

      final secondEntry = root.entries[1];
      expect(secondEntry.key, isA<CstEmpty>());
      expect(secondEntry.colon, 9);
      expect(secondEntry.value.value.value, 'c');
    });

    test('explicit block-collection key does not steal parent mapping colon',
        () {
      const rootSource = '? ? - x\n: c\n';
      final rootDoc = CstDocument.parse(rootSource);
      final rootMap = rootDoc.root as CstBlockMap;
      expect(rootMap.entries, hasLength(1));
      expect(rootMap.entries.single.colon, 8);
      final innerMap = rootMap.entries.single.key as CstBlockMap;
      expect(innerMap.entries.single.colon, isNull);
      expect(innerMap.entries.single.key, isA<CstBlockSeq>());

      const nestedSource = '- ? ? - x\n  : c\n';
      final nestedDoc = CstDocument.parse(nestedSource);
      final outerSeq = nestedDoc.root as CstBlockSeq;
      final nestedMap = outerSeq.entries.single.value as CstBlockMap;
      expect(nestedMap.entries.single.colon, 12);
      final nestedInnerMap = nestedMap.entries.single.key as CstBlockMap;
      expect(nestedInnerMap.entries.single.colon, isNull);
    });

    test('26DV_0: block mapping with anchor and alias key parses into CST', () {
      const source = '&node1 a: 1\n&node2 b: 2\ntop3: &node3\n  *node1 : 3\n';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstBlockMap;
      final top3 = root.entries[2].value as CstBlockMap;
      expect(top3.entries.single.key, isA<CstAlias>());
    });

    test('CstError formats offset and message', () {
      final error = CstError('Test message', 42);
      expect(error.offset, 42);
      expect(error.message, 'Test message');
      expect(error.toString(), 'CstError at 42: Test message');
    });

    test('anchor on flow pair key attaches to key, not CstFlowPair', () {
      const source = '[&x {a: 1}: b]';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstFlowSeq;
      final pair = root.entries.single.value as CstFlowPair;
      expect(pair.hasProperties, isFalse);
      final keyMap = pair.key as CstFlowMap;
      expect(keyMap.hasProperties, isTrue);
      expect(source.substring(keyMap.start, keyMap.contentStart), '&x ');
      expect(source.substring(keyMap.contentStart, keyMap.end), '{a: 1}');
    });

    test('anchored block map has truthful lineStart and isCompact == false',
        () {
      const source = 'a: &x\n  b: 1\n  c: 2\n';
      final doc = CstDocument.parse(source);
      final root = doc.root as CstBlockMap;
      final inner = root.entries.single.value as CstBlockMap;
      expect(inner.hasProperties, isTrue);
      expect(inner.isCompact, isFalse);
      expect(inner.entries.first.lineStart, 6);
      expect(doc.columnOf(inner.entries.first.lineStart), 0);
      expect(doc.columnOf(inner.entries.first.keyStart), 2);
    });

    test(
        'anchor on first block map key stays on key; anchor on own line '
        'attaches to map', () {
      final keyDoc = CstDocument.parse('a:\n  &k b: 1\n');
      final keyInner =
          (keyDoc.root as CstBlockMap).entries.single.value as CstBlockMap;
      expect(keyInner.hasProperties, isFalse);
      expect(keyInner.entries.single.key.hasProperties, isTrue);

      final mapDoc = CstDocument.parse('a:\n  &k\n  b: 1\n');
      final mapInner =
          (mapDoc.root as CstBlockMap).entries.single.value as CstBlockMap;
      expect(mapInner.hasProperties, isTrue);
      expect(mapInner.entries.single.key.hasProperties, isFalse);
    });

    test('compact block sequence and map set isCompact == true', () {
      final seqDoc = CstDocument.parse('- - 1\n  - 2\n');
      final outerSeq = seqDoc.root as CstBlockSeq;
      expect(outerSeq.isCompact, isFalse);
      expect((outerSeq.entries.single.value as CstBlockSeq).isCompact, isTrue);

      final mapDoc = CstDocument.parse('- a: 1\n  b: 2\n');
      final outerMapSeq = mapDoc.root as CstBlockSeq;
      expect(
          (outerMapSeq.entries.single.value as CstBlockMap).isCompact, isTrue);
    });

    test('handles deeply nested flow sequences matching package:yaml depth',
        () {
      final source = '${'[' * 2000}${']' * 2000}';
      final doc = CstDocument.parse(source);
      expect(doc.root, isA<CstFlowSeq>());
    });

    test('line table handles EOF after trailing newline', () {
      final doc = CstDocument.parse('a: 1\n');
      expect(doc.lineStartOf(5), 5);
      expect(doc.columnOf(5), 0);
      expect(doc.lineContentEndOf(5), 5);
      expect(doc.lineBreakEndOf(5), 5);
    });

    test('lineEnding uses majority vote', () {
      expect(CstDocument.parse('a: 1\nb: 2\r\nc: 3\n').lineEnding, '\n');
      expect(CstDocument.parse('a: 1\r\nb: 2\r\nc: 3\n').lineEnding, '\r\n');
    });

    test('commentInRange and commentsInRange use binary search accurately', () {
      final lines = [
        for (var i = 0; i < 50; i++) 'k$i: $i # comment $i',
      ];
      final source = '${lines.join('\n')}\n';
      final doc = CstDocument.parse(source);
      expect(doc.comments, hasLength(50));
      final secondLineStart = doc.lineBreakEndOf(0);
      final secondLineEnd = doc.lineContentEndOf(secondLineStart);
      expect(doc.commentInRange(secondLineStart, secondLineEnd)?.span.text,
          '# comment 1');
      expect(
        doc.commentsInRange(0, secondLineEnd).map((c) => c.span.text),
        ['# comment 0', '# comment 1'],
      );
      expect(doc.commentInRange(secondLineEnd, secondLineEnd), isNull);
    });

    test('structural dump golden on mixed features', () {
      const source = 'a: &x [1, {b: 2}]\nc: *x\n';
      final doc = CstDocument.parse(source);
      expect(
        dumpNode(doc.root!, source),
        'BlockMap({'
        'Entry(line=0 key=Scalar([0..1) "a") :=1 '
        'val=FlowSeq(props=[3..6) [Scalar([7..8) "1"), '
        'FlowMap({Scalar([11..12) "b"): Scalar([14..15) "2")})])), '
        'Entry(line=18 key=Scalar([18..19) "c") :=19 '
        'val=Alias([21..23) "*x"))'
        '})',
      );
    });

    test('structural dump goldens on ownership-sensitive constructs', () {
      final goldens = <(String, String, String)>[
        (
          'anchor on first block map key vs anchor on map',
          'a:\n  &k b: 1\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockMap({Entry(line=3 key=Scalar(props=[5..8) [8..9) "b") '
              ':=9 val=Scalar([11..12) "1"))}))})',
        ),
        (
          'anchor on block map',
          'a:\n  &k\n  b: 1\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockMap(props=[5..8) {Entry(line=8 '
              'key=Scalar([10..11) "b") :=11 val=Scalar([13..14) "1"))}))})',
        ),
        (
          'compact block map inside block sequence',
          '- a: 1\n  b: 2\n',
          'BlockSeq([Entry(line=0 dash=0 BlockMap(compact {'
              'Entry(line=2 key=Scalar([2..3) "a") :=3 '
              'val=Scalar([5..6) "1")), '
              'Entry(line=7 key=Scalar([9..10) "b") :=10 '
              'val=Scalar([12..13) "2"))}))])',
        ),
        (
          'compact block sequence inside block sequence',
          '- - 1\n  - 2\n',
          'BlockSeq([Entry(line=0 dash=0 BlockSeq(compact ['
              'Entry(line=2 dash=2 Scalar([4..5) "1")), '
              'Entry(line=6 dash=8 Scalar([10..11) "2"))]))])',
        ),
        (
          'explicit block keys with and without values',
          '? a\n: 1\n? b\n',
          'BlockMap({Entry(line=0 ?=0 key=Scalar([2..3) "a") :=4 '
              'val=Scalar([6..7) "1")), '
              'Entry(line=8 ?=8 key=Scalar([10..11) "b") val=Empty(@11))})',
        ),
        (
          'complex explicit flow-sequence key',
          '? [1, 2]\n: a\n',
          'BlockMap({Entry(line=0 ?=0 key=FlowSeq(['
              'Scalar([3..4) "1"), Scalar([6..7) "2")]) :=9 '
              'val=Scalar([11..12) "a"))})',
        ),
        (
          'flow pairs inside flow sequence',
          '[a: 1, ? b: 2]',
          'FlowSeq([FlowPair(Scalar([1..2) "a"): Scalar([4..5) "1")), '
              'FlowPair(Scalar([9..10) "b"): Scalar([12..13) "2"))])',
        ),
        (
          'block scalar with header comment',
          'a: | # hdr\n  x\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              r'val=Scalar([3..14) "| # hdr\n  x"))})',
        ),
        (
          'empty values in block map',
          'a:\nb: 2\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=Empty(@2)), Entry(line=3 key=Scalar([3..4) "b") :=4 '
              'val=Scalar([6..7) "2"))})',
        ),
        (
          'empty values in block sequence',
          '-\n- 2\n',
          'BlockSeq([Entry(line=0 dash=0 Empty(@1)), '
              'Entry(line=2 dash=2 Scalar([4..5) "2"))])',
        ),
        (
          'tagged block map',
          'a: !!map\n  b: 1\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockMap(props=[3..9) {Entry(line=9 '
              'key=Scalar([11..12) "b") :=12 val=Scalar([14..15) "1"))}))})',
        ),
        (
          '1-space indentation',
          'a:\n b: 1\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockMap({Entry(line=3 key=Scalar([4..5) "b") :=5 '
              'val=Scalar([7..8) "1"))}))})',
        ),
        (
          '3-space indentation',
          'a:\n   - x\n   - y\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockSeq([Entry(line=3 dash=6 Scalar([8..9) "x")), '
              'Entry(line=10 dash=13 Scalar([15..16) "y"))]))})',
        ),
        (
          '4-space indentation',
          'a:\n    b:\n        c: 1\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              'val=BlockMap({Entry(line=3 key=Scalar([7..8) "b") :=8 '
              'val=BlockMap({Entry(line=10 key=Scalar([18..19) "c") :=19 '
              'val=Scalar([21..22) "1"))}))}))})',
        ),
        (
          'tab-indented document and tab after colon',
          '\ta:\t1\n',
          'BlockMap({Entry(line=0 key=Scalar([1..2) "a") :=2 '
              'val=Scalar([4..5) "1"))})',
        ),
        (
          'indented root block sequence',
          ' - 1\n - 2\n',
          'BlockSeq([Entry(line=0 dash=1 Scalar([3..4) "1")), '
              'Entry(line=5 dash=6 Scalar([8..9) "2"))])',
        ),
        (
          'explicit document start with root block scalar',
          '--- |\n  hello\n',
          r'Scalar([4..13) "|\n  hello")',
        ),
        (
          'BOM-prefixed document',
          '\uFEFFa: 1\n',
          'BlockMap({Entry(line=1 key=Scalar([1..2) "a") :=2 '
              'val=Scalar([4..5) "1"))})',
        ),
        (
          'multiline plain scalar',
          'a: foo\n  bar\n',
          'BlockMap({Entry(line=0 key=Scalar([0..1) "a") :=1 '
              r'val=Scalar([3..12) "foo\n  bar"))})',
        ),
      ];

      for (final (description, source, expected) in goldens) {
        final doc = CstDocument.parse(source);
        expect(dumpNode(doc.root!, source), expected, reason: description);
      }

      // Also verify block scalar headerComment ownership and anchor-on-empty.
      final hdrDoc = CstDocument.parse('a: | # hdr\n  x\n');
      final hdrScalar =
          (hdrDoc.root as CstBlockMap).entries.single.value as CstScalar;
      expect(hdrScalar.headerComment?.span.text, '# hdr');

      final emptyAnchorDoc = CstDocument.parse('a: &e\nb: *e\n');
      final emptyAnchorMap = emptyAnchorDoc.root as CstBlockMap;
      expect(emptyAnchorMap.entries[0].value.hasProperties, isTrue);
      expect(emptyAnchorMap.entries[1].value, isA<CstAlias>());
    });
  });

  group('tiling verifier negative tests', () {
    void expectCstError(void Function() fn, String messageContains) {
      expect(
        fn,
        throwsA(
          isA<CstError>().having(
            (e) => e.message,
            'message',
            contains(messageContains),
          ),
        ),
      );
    }

    test('rejects unexpected content in prefix, suffix, and empty document',
        () {
      final doc = CstDocument.parse('a: 1\n');
      final map = doc.root as CstBlockMap;
      final firstEntry = map.entries.single;
      // Pretend root starts at `1`, leaving `a: ` as unexpected prefix.
      expectCstError(
        () => checkCstTilingForTesting(
          source: doc.source,
          root: firstEntry.value,
          value: doc.value,
          tokens: doc.tokens,
        ),
        'unexpected content in document prefix',
      );
      // Pretend document is empty when it has tokens.
      expectCstError(
        () => checkCstTilingForTesting(
          source: doc.source,
          root: null,
          value: doc.value,
          tokens: doc.tokens,
        ),
        'unexpected content in empty document',
      );
      // Point closeStart at `'2'` instead of `']'` to trigger indicator error.
      final seqDoc = CstDocument.parse('[1, 2]');
      final seq = seqDoc.root as CstFlowSeq;
      expectCstError(
        () => checkCstTilingForTesting(
          source: seqDoc.source,
          root: CstFlowSeq(
            start: seq.start,
            contentStart: seq.contentStart,
            entries: [seq.entries.first],
            closeStart: 4,
            isMultiline: false,
            value: seq.value,
          ),
          value: seqDoc.value,
          tokens: seqDoc.tokens,
        ),
        'expected flow collection closing delimiter',
      );
    });

    test('rejects non-trivia gap and overlapping slots', () {
      final doc = CstDocument.parse('a: 1\nb: 2\n');
      final map = doc.root as CstBlockMap;
      final first = map.entries[0];
      final second = map.entries[1];

      // Drop first entry so `a: 1` sits in the prefix before `b: 2`.
      expectCstError(
        () => checkCstTilingForTesting(
          source: doc.source,
          root: CstBlockMap(
            start: map.start,
            contentStart: map.contentStart,
            entries: [second],
            isCompact: false,
            value: map.value,
          ),
          value: doc.value,
          tokens: doc.tokens,
        ),
        'whitespace or comments',
      );

      // Duplicate first entry so the second slot starts before cursor.
      expectCstError(
        () => checkCstTilingForTesting(
          source: doc.source,
          root: CstBlockMap(
            start: map.start,
            contentStart: map.contentStart,
            entries: [first, first],
            isCompact: false,
            value: map.value,
          ),
          value: doc.value,
          tokens: doc.tokens,
        ),
        'before the previous slot ended',
      );
    });

    test('rejects mismatched scalar span, alias target, and node properties',
        () {
      final scalarDoc = CstDocument.parse('hello\n');
      final scalar = scalarDoc.root as CstScalar;
      expectCstError(
        () => checkCstTilingForTesting(
          source: scalarDoc.source,
          root: CstScalar(
            start: 0,
            contentStart: 0,
            end: 4,
            value: scalar.value,
          ),
          value: scalarDoc.value,
          tokens: scalarDoc.tokens,
        ),
        'does not match YamlScalar span',
      );

      // Non-property text (`h`) inside [start, contentStart).
      expectCstError(
        () => checkCstTilingForTesting(
          source: scalarDoc.source,
          root: CstScalar(
            start: 0,
            contentStart: 1,
            end: scalar.end,
            value: scalar.value,
          ),
          value: scalarDoc.value,
          tokens: scalarDoc.tokens,
        ),
        'unexpected token in node properties',
      );

      // CstAlias pointing to a non-alias scalar token.
      expectCstError(
        () => checkCstTilingForTesting(
          source: scalarDoc.source,
          root: CstAlias(start: 0, end: scalar.end, value: scalar.value),
          value: scalarDoc.value,
          tokens: scalarDoc.tokens,
        ),
        'does not match an alias token',
      );

      // CstAlias pointing forward to a node whose span starts after the alias.
      final aliasDoc = CstDocument.parse('a: &x 1\nb: *x\nc: 2\n');
      final aliasMap = aliasDoc.root as CstBlockMap;
      final aliasEntry = aliasMap.entries[1];
      final realAlias = aliasEntry.value as CstAlias;
      final fakeForwardAlias = CstAlias(
        start: realAlias.start,
        end: realAlias.end,
        value: aliasMap.entries[2].value.value,
      );
      expectCstError(
        () => checkCstTilingForTesting(
          source: aliasDoc.source,
          root: CstBlockMap(
            start: aliasMap.start,
            contentStart: aliasMap.contentStart,
            entries: [
              aliasMap.entries[0],
              CstBlockMapEntry(
                start: aliasEntry.start,
                lineStart: aliasEntry.lineStart,
                questionMark: aliasEntry.questionMark,
                key: aliasEntry.key,
                colon: aliasEntry.colon,
                value: fakeForwardAlias,
                end: aliasEntry.end,
                hasSeparatorComment: aliasEntry.hasSeparatorComment,
              ),
              aliasMap.entries[2],
            ],
            isCompact: false,
            value: aliasMap.value,
          ),
          value: aliasDoc.value,
          tokens: aliasDoc.tokens,
        ),
        'points to node starting at',
      );
    });
  });

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
      'tag on flow map': '- !!map {a: 1}\n',
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
      test(name, () => expect(CstDocument.parse(source).source, source));
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

    test('every document the parser accepts is tiled strictly', () {
      if (!suite.existsSync()) {
        fail('yaml-test-suite not available at ${suite.path}');
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
          final rawSource = testCase['yaml'];
          if (rawSource is! String) continue;
          final source = _replaceSpecialCharacters(rawSource);

          // Only documents our own parser accepts are in scope.
          try {
            withYamlWarningCallback(() => loadYamlNode(source));
          } catch (_) {
            continue;
          }

          accepted++;
          try {
            withYamlWarningCallback(() => CstDocument.parse(source));
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
