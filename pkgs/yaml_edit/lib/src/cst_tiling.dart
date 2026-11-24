// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cst.dart';

/// Runs the tiling verifier on an arbitrary [root] and [tokens] against
/// [source], throwing [CstError] on any tiling violation.
@visibleForTesting
void checkCstTilingForTesting({
  required String source,
  required CstNode? root,
  required YamlNode value,
  required List<YamlToken> tokens,
}) {
  final lineTable = _LineTable(source);
  final tokensByOffset = <int, YamlToken>{
    for (final token in tokens) token.span.start.offset: token,
  };
  final comments = [
    for (final token in tokens)
      if (token.kind == YamlTokenKind.comment) token,
  ];
  final document = CstDocument._(
    source: source,
    root: root,
    value: value,
    tokens: tokens,
    comments: comments,
    lineEnding: lineTable.lineEnding,
    lineTable: lineTable,
  );
  _checkTiling(document, tokensByOffset);
}

/// Verifies that [document]'s slots tile its source accurately.
///
/// Walks the tree iteratively in source order and checks that:
/// 1. The prefix `[0, root.start)` holds only whitespace, BOM, comments,
///    directives, and document markers (`---`/`...`).
/// 2. The suffix `[root.end, source.length)` holds only whitespace, BOM,
///    comments, and document end markers (`...`).
/// 3. Slot boundaries are monotonically non-decreasing (disjoint and ordered).
/// 4. Every structural indicator (`-`, `?`, `:`, `,`, `[`, `]`, `{`, `}`)
///    matches both its source character and its [YamlTokenKind].
/// 5. Every gap between slots holds only whitespace and whole
///    [YamlTokenKind.comment] tokens.
/// 6. Node property regions `[start, contentStart)` start on an anchor or tag,
///    hold at most one anchor and one tag, and for block collections end at
///    the line break after the last property.
/// 7. Every [CstScalar], [CstFlowCollection], [CstBlockSeq], [CstBlockMap],
///    and [CstEmpty] matches its [YamlNode] span/children, every [CstAlias]
///    resolves to the [YamlNode] bound by the active `&anchor` of the same
///    name, and [CstFlowPair] only appears directly inside a [CstFlowSeq].
/// 8. Block entry `isCompact`, `lineStart`, `colon` alignment, trailing line
///    consumption (`entry.end`), and derived flags (`hasSeparatorComment`,
///    `headerComment`, `isMultiline`) match the source independently.
///
/// Throws a [CstError] if any check fails.
void _checkTiling(CstDocument document, Map<int, YamlToken> tokensByOffset) {
  final source = document.source;
  var cursor = 0;

  void check(bool condition, int offset, String Function() message) {
    if (!condition) throw CstError(message(), offset);
  }

  bool isHorizontalSpace(int codeUnit) =>
      codeUnit == 0x20 || // space
      codeUnit == 0x09; // tab

  bool isBreakChar(int codeUnit) =>
      codeUnit == 0x0A || // LF
      codeUnit == 0x0D; // CR

  bool isTriviaChar(int codeUnit) =>
      isHorizontalSpace(codeUnit) || isBreakChar(codeUnit);

  bool hasNonTriviaBeforeOnLine(int offset) {
    final lineStart = document.lineStartOf(offset);
    for (var i = lineStart; i < offset; i++) {
      final unit = source.codeUnitAt(i);
      if (!isHorizontalSpace(unit) && unit != 0xFEFF) return true;
    }
    return false;
  }

  /// Expected `lineStart` for a non-compact block entry anchored at [anchor]:
  /// the start of [anchor]'s line, advanced past a leading BOM if present.
  int expectedLineStartOf(int anchor) {
    var lineStart = document.lineStartOf(anchor);
    if (lineStart < anchor && source.codeUnitAt(lineStart) == 0xFEFF) {
      lineStart++;
    }
    return lineStart;
  }

  /// Computes the expected `entry.end` for a block entry with [value].
  int expectedBlockEntryEnd(
    CstNode value, {
    required bool alreadyTerminatedLine,
  }) {
    if (alreadyTerminatedLine) return value.end;
    final valueEnd = value.end;
    var probe = valueEnd;
    while (
        probe < source.length && isHorizontalSpace(source.codeUnitAt(probe))) {
      probe++;
    }
    if (tokensByOffset[probe] case final token?
        when token.kind == YamlTokenKind.comment) {
      probe = token.span.end.offset;
    }
    return probe == document.lineContentEndOf(valueEnd)
        ? document.lineBreakEndOf(valueEnd)
        : valueEnd;
  }

  /// Checks a prefix or suffix region where only whitespace, BOM, and tokens
  /// of [allowedKinds] may appear.
  void checkEdgeRegion(
    int start,
    int end,
    Set<YamlTokenKind> allowedKinds,
    String what,
  ) {
    check(
      end >= start && end <= source.length,
      start,
      () => '$what bounds [$start, $end) out of range',
    );
    var index = start;
    while (index < end) {
      final codeUnit = source.codeUnitAt(index);
      if (isTriviaChar(codeUnit) || codeUnit == 0xFEFF) {
        index++;
      } else if (tokensByOffset[index] case final token?
          when allowedKinds.contains(token.kind) &&
              token.span.end.offset <= end) {
        index = token.span.end.offset;
      } else {
        throw CstError(
          'unexpected content in $what: '
          '${_describe(source.substring(index, end))}',
          index,
        );
      }
    }
  }

  /// Advances the cursor to [offset], requiring `[cursor, offset)` to hold only
  /// whitespace and complete [YamlTokenKind.comment] tokens.
  void whitespaceAndComments(int offset, String what) {
    check(
      offset >= cursor,
      offset,
      () => 'slot "$what" starts at $offset, before the previous slot ended at '
          '$cursor',
    );
    var index = cursor;
    while (index < offset) {
      if (isTriviaChar(source.codeUnitAt(index))) {
        index++;
      } else if (tokensByOffset[index] case final token?
          when token.kind == YamlTokenKind.comment &&
              token.span.end.offset <= offset) {
        index = token.span.end.offset;
      } else {
        throw CstError(
          'the source before "$what" was taken to be whitespace or comments, '
          'but holds ${_describe(source.substring(cursor, offset))}',
          index,
        );
      }
    }
    cursor = offset;
  }

  // Active anchor name -> anchored YamlNode in document source order.
  final anchors = <String, YamlNode>{};

  /// Advances the cursor over `[cursor, offset)` requiring only whitespace,
  /// comments, and at most one anchor and one tag.
  void properties(
    int offset,
    YamlNode owner, {
    required bool isBlockCollection,
  }) {
    check(
      offset >= cursor,
      offset,
      () => 'node properties end at $offset, before they started at $cursor',
    );
    if (offset == cursor) return;

    final start = cursor;
    var index = start;
    var anchorCount = 0;
    var tagCount = 0;
    int? lastPropertyEnd;

    while (index < offset) {
      if (isTriviaChar(source.codeUnitAt(index))) {
        index++;
      } else if (tokensByOffset[index] case final token?
          when (token.kind == YamlTokenKind.anchor ||
                  token.kind == YamlTokenKind.tag ||
                  token.kind == YamlTokenKind.comment) &&
              token.span.end.offset <= offset) {
        if (token.kind == YamlTokenKind.anchor) {
          anchorCount++;
          check(
            anchorCount == 1,
            index,
            () => 'duplicate anchor token in node properties at $index',
          );
          anchors[token.span.text.substring(1)] = owner;
          lastPropertyEnd = token.span.end.offset;
        } else if (token.kind == YamlTokenKind.tag) {
          tagCount++;
          check(
            tagCount == 1,
            index,
            () => 'duplicate tag token in node properties at $index',
          );
          lastPropertyEnd = token.span.end.offset;
        }
        index = token.span.end.offset;
      } else {
        throw CstError(
          'unexpected token in node properties: '
          '${_describe(source.substring(start, offset))}',
          index,
        );
      }
    }

    final firstToken = tokensByOffset[start];
    check(
      lastPropertyEnd != null &&
          firstToken != null &&
          (firstToken.kind == YamlTokenKind.anchor ||
              firstToken.kind == YamlTokenKind.tag),
      start,
      () => 'node properties [$start, $offset) must start with an anchor or '
          'tag',
    );
    if (isBlockCollection) {
      final expectedContentStart = document.lineBreakEndOf(lastPropertyEnd!);
      check(
        offset == expectedContentStart &&
            expectedContentStart > lastPropertyEnd,
        offset,
        () => 'block collection properties [$start, $offset) must end at line '
            'break $expectedContentStart after last property',
      );
    }
    cursor = offset;
  }

  String indicatorChar(YamlTokenKind kind) => switch (kind) {
        YamlTokenKind.blockEntry => '-',
        YamlTokenKind.key => '?',
        YamlTokenKind.value => ':',
        YamlTokenKind.flowEntry => ',',
        YamlTokenKind.flowSequenceStart => '[',
        YamlTokenKind.flowSequenceEnd => ']',
        YamlTokenKind.flowMappingStart => '{',
        YamlTokenKind.flowMappingEnd => '}',
        _ => throw StateError('Not an indicator token kind: $kind'),
      };

  /// Advances the cursor past an indicator matching [expectedKind].
  void indicator(int offset, YamlTokenKind expectedKind, String what) {
    whitespaceAndComments(offset, what);
    final char = indicatorChar(expectedKind);
    final token = tokensByOffset[offset];
    if (offset >= source.length ||
        source[offset] != char ||
        token == null ||
        token.kind != expectedKind ||
        token.span.length != 1) {
      final found = token != null
          ? '${token.kind} (${_describe(token.span.text)})'
          : offset >= source.length
              ? '<end of input>'
              : _describe(source[offset]);
      throw CstError(
        'expected $what ("$char", $expectedKind) at $offset but found $found',
        offset,
      );
    }
    cursor = offset + 1;
  }

  /// Advances the cursor over a scalar or alias body.
  void opaque(int offset, String what) {
    check(
      offset >= cursor,
      offset,
      () => 'slot "$what" ends at $offset, before it started at $cursor',
    );
    cursor = offset;
  }

  void checkNoColonEmpty(CstNode value, String what) {
    check(
      value is CstEmpty,
      value.start,
      () => '$what without ":" must have a CstEmpty value',
    );
  }

  void checkContiguousEntries(
    int containerStart,
    int count,
    int Function(int) entryStart,
    int Function(int) entryEnd,
    String kind,
  ) {
    if (count == 0) return;
    check(
      entryStart(0) == containerStart,
      entryStart(0),
      () => '$kind first entry starts at ${entryStart(0)}, expected '
          '$containerStart',
    );
    for (var i = 1; i < count; i++) {
      check(
        entryStart(i) == entryEnd(i - 1),
        entryStart(i),
        () => '$kind entry $i starts at ${entryStart(i)}, expected '
            '${entryEnd(i - 1)}',
      );
    }
  }

  void checkBlockHeader(
    CstNode node,
    int entryCount,
    bool isCompact,
    String kind,
  ) {
    check(entryCount > 0, node.start, () => '$kind has no entries');
    final expectedCompact = hasNonTriviaBeforeOnLine(node.contentStart);
    check(
      isCompact == expectedCompact,
      node.contentStart,
      () => '$kind at ${node.start} has isCompact=$isCompact '
          'but expected $expectedCompact',
    );
  }

  void checkBlockEntryStart(
    int entryStart,
    int lineStart,
    int anchor, {
    required bool isFirstCompact,
    required String kind,
  }) {
    whitespaceAndComments(entryStart, '$kind entry');
    whitespaceAndComments(lineStart, '$kind entry line');
    if (isFirstCompact) {
      check(
        lineStart == entryStart && lineStart == anchor,
        lineStart,
        () => 'compact $kind first entry lineStart $lineStart must equal '
            'start ($entryStart) and anchor ($anchor)',
      );
    } else {
      final expectedLineStart = expectedLineStartOf(anchor);
      check(
        lineStart == expectedLineStart,
        lineStart,
        () => '$kind entry lineStart $lineStart does not match line start '
            '$expectedLineStart',
      );
    }
  }

  void checkBlockEntryEnd(
    int entryEnd,
    CstNode value, {
    required bool alreadyTerminatedLine,
    required int? sepStart,
    required bool hasSeparatorComment,
    required int anchor,
    required String kind,
  }) {
    final expectedEnd = expectedBlockEntryEnd(
      value,
      alreadyTerminatedLine: alreadyTerminatedLine,
    );
    check(
      entryEnd == expectedEnd,
      entryEnd,
      () => '$kind entry ends at $entryEnd, expected $expectedEnd',
    );
    final expectedSepComment = sepStart != null &&
        document.commentInRange(sepStart + 1, value.start) != null;
    check(
      hasSeparatorComment == expectedSepComment,
      anchor,
      () => '$kind entry at $anchor has '
          'hasSeparatorComment=$hasSeparatorComment, expected '
          '$expectedSepComment',
    );
    whitespaceAndComments(entryEnd, 'end of $kind entry');
  }

  const prefixKinds = {
    YamlTokenKind.versionDirective,
    YamlTokenKind.tagDirective,
    YamlTokenKind.unknownDirective,
    YamlTokenKind.documentStart,
    YamlTokenKind.documentEnd,
    YamlTokenKind.comment,
  };
  const suffixKinds = {
    YamlTokenKind.documentEnd,
    YamlTokenKind.comment,
  };

  final root = document.root;
  if (root == null) {
    checkEdgeRegion(0, source.length, prefixKinds, 'empty document');
    return;
  }

  checkEdgeRegion(0, root.start, prefixKinds, 'document prefix');
  cursor = root.start;

  // Iterative traversal to avoid overflowing the Dart stack on deeply nested
  // flow collections.
  final stack = <void Function()>[];

  void scheduleNode(CstNode node, {bool allowFlowPair = false}) {
    stack.add(() {
      whitespaceAndComments(node.start, 'node');
      properties(
        node.contentStart,
        node.value,
        isBlockCollection: node is CstBlockSeq || node is CstBlockMap,
      );
      switch (node) {
        case CstScalar():
          check(
            node.start == node.value.span.start.offset &&
                node.end == node.value.span.end.offset,
            node.start,
            () => 'scalar slot [${node.start}, ${node.end}) does not match '
                'YamlScalar span [${node.value.span.start.offset}, '
                '${node.value.span.end.offset})',
          );
          if (node.contentStart == node.end) {
            check(
              node.hasProperties,
              node.start,
              () => 'zero-width CstScalar at ${node.start} without properties',
            );
          } else {
            final scalarToken = tokensByOffset[node.contentStart];
            check(
              scalarToken != null &&
                  scalarToken.kind == YamlTokenKind.scalar &&
                  scalarToken.span.end.offset == node.end,
              node.contentStart,
              () => 'scalar content [${node.contentStart}, ${node.end}) does '
                  'not match a scalar token',
            );
          }
          final expectedHeaderComment =
              node.value.style == ScalarStyle.LITERAL ||
                      node.value.style == ScalarStyle.FOLDED
                  ? document.commentInRange(
                      node.contentStart + 1,
                      document.lineBreakEndOf(node.contentStart),
                    )
                  : null;
          check(
            identical(node.headerComment, expectedHeaderComment),
            node.contentStart,
            () => 'scalar at ${node.start} has mismatched headerComment',
          );
          opaque(node.end, 'scalar');
        case CstAlias():
          final aliasToken = tokensByOffset[node.start];
          check(
            aliasToken != null &&
                aliasToken.kind == YamlTokenKind.alias &&
                aliasToken.span.end.offset == node.end,
            node.start,
            () => 'alias slot [${node.start}, ${node.end}) does not match an '
                'alias token',
          );
          check(
            node.value.span.start.offset < node.start,
            node.start,
            () => 'alias at ${node.start} points to node starting at '
                '${node.value.span.start.offset}',
          );
          final aliasName = aliasToken!.span.text.substring(1);
          final target = anchors[aliasName];
          check(
            target != null && identical(target, node.value),
            node.start,
            () => 'alias "*$aliasName" at ${node.start} does not match '
                'anchored node',
          );
          opaque(node.end, 'alias');
        case CstEmpty():
          check(
            node.value.span.length == 0,
            node.start,
            () => 'empty node at ${node.start} has non-empty YamlScalar span '
                '[${node.value.span.start.offset}, '
                '${node.value.span.end.offset})',
          );
          opaque(node.end, 'empty');
        case CstBlockSeq():
          checkBlockHeader(
              node, node.entries.length, node.isCompact, 'block sequence');
          stack.add(() {
            final actualStart =
                node.hasProperties ? node.start : node.entries.first.dashStart;
            final expectedStart = node.value.span.start.offset;
            check(
              actualStart == expectedStart,
              actualStart,
              () => 'block sequence start $actualStart does not match YamlList '
                  'span start $expectedStart',
            );
            check(
              node.entries.length == node.value.nodes.length,
              node.start,
              () => 'block sequence has ${node.entries.length} CST entries but '
                  '${node.value.nodes.length} YamlList elements',
            );
            checkContiguousEntries(
              node.contentStart,
              node.entries.length,
              (i) => node.entries[i].start,
              (i) => node.entries[i].end,
              'block sequence',
            );
            for (var i = 0; i < node.entries.length; i++) {
              check(
                identical(node.entries[i].value.value, node.value.nodes[i]),
                node.entries[i].start,
                () => 'block sequence entry $i does not match YamlList element',
              );
            }
          });
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            final isFirstCompact = i == 0 && node.isCompact;
            stack.add(() => checkBlockEntryEnd(
                  entry.end,
                  entry.value,
                  alreadyTerminatedLine:
                      entry.value is CstBlockSeq || entry.value is CstBlockMap,
                  sepStart: entry.dashStart,
                  hasSeparatorComment: entry.hasSeparatorComment,
                  anchor: entry.dashStart,
                  kind: 'block sequence',
                ));
            scheduleNode(entry.value);
            stack.add(() {
              checkBlockEntryStart(
                entry.start,
                entry.lineStart,
                entry.dashStart,
                isFirstCompact: isFirstCompact,
                kind: 'block sequence',
              );
              indicator(
                entry.dashStart,
                YamlTokenKind.blockEntry,
                'block sequence entry indicator',
              );
            });
          }
        case CstBlockMap():
          checkBlockHeader(
              node, node.entries.length, node.isCompact, 'block mapping');
          stack.add(() {
            final actualStart =
                node.hasProperties ? node.start : node.entries.first.keyStart;
            final expectedStart = node.value.span.start.offset;
            check(
              actualStart == expectedStart,
              actualStart,
              () => 'block mapping start $actualStart does not match YamlMap '
                  'span start $expectedStart',
            );
            check(
              node.entries.length == node.value.nodes.length,
              node.start,
              () => 'block mapping has ${node.entries.length} CST entries but '
                  '${node.value.nodes.length} YamlMap entries',
            );
            checkContiguousEntries(
              node.contentStart,
              node.entries.length,
              (i) => node.entries[i].start,
              (i) => node.entries[i].end,
              'block mapping',
            );
            var i = 0;
            for (final mapEntry in node.value.nodes.entries) {
              final entry = node.entries[i];
              check(
                identical(entry.key.value, mapEntry.key) &&
                    identical(entry.value.value, mapEntry.value),
                entry.start,
                () => 'block mapping entry $i does not match YamlMap entry',
              );
              i++;
            }
          });
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            final isFirstCompact = i == 0 && node.isCompact;
            stack.add(() => checkBlockEntryEnd(
                  entry.end,
                  entry.value,
                  alreadyTerminatedLine: entry.value is CstBlockSeq ||
                      entry.value is CstBlockMap ||
                      (entry.colon == null &&
                          (entry.key is CstBlockSeq ||
                              entry.key is CstBlockMap)),
                  sepStart: entry.colon,
                  hasSeparatorComment: entry.hasSeparatorComment,
                  anchor: entry.keyStart,
                  kind: 'block mapping',
                ));
            scheduleNode(entry.value);
            if (entry.colon case final colon?) {
              stack.add(() {
                if (document.lineStartOf(colon) >
                    document.lineStartOf(entry.key.contentEnd)) {
                  check(
                    entry.questionMark != null,
                    colon,
                    () => 'multiline block mapping colon at $colon without '
                        'explicit "?" indicator',
                  );
                  final expectedCol = document.columnOf(entry.keyStart);
                  final actualCol = document.columnOf(colon);
                  check(
                    actualCol == expectedCol,
                    colon,
                    () => 'multiline block mapping colon at $colon is at '
                        'column $actualCol, expected $expectedCol',
                  );
                }
                indicator(colon, YamlTokenKind.value, 'key/value separator');
              });
            } else {
              stack.add(
                  () => checkNoColonEmpty(entry.value, 'block mapping entry'));
            }
            scheduleNode(entry.key);
            stack.add(() {
              checkBlockEntryStart(
                entry.start,
                entry.lineStart,
                entry.keyStart,
                isFirstCompact: isFirstCompact,
                kind: 'block mapping',
              );
              if (entry.questionMark case final questionMark?) {
                indicator(
                  questionMark,
                  YamlTokenKind.key,
                  'explicit key indicator',
                );
              }
            });
          }
        case CstFlowPair():
          check(
            allowFlowPair,
            node.start,
            () => 'CstFlowPair at ${node.start} is only valid directly inside '
                'a CstFlowSeq',
          );
          check(
            !node.hasProperties,
            node.start,
            () => 'CstFlowPair at ${node.start} must not carry node properties',
          );
          check(
            node.value.nodes.length == 1,
            node.start,
            () => 'CstFlowPair at ${node.start} must have 1 YamlMap entry, '
                'found ${node.value.nodes.length}',
          );
          final pairAnchor = node.questionMark ?? node.key.start;
          check(
            pairAnchor == node.start,
            node.start,
            () => 'CstFlowPair starts at ${node.start}, expected $pairAnchor',
          );
          final mapEntry = node.value.nodes.entries.single;
          stack.add(() => check(
                identical(node.key.value, mapEntry.key) &&
                    identical(node.pairValue.value, mapEntry.value),
                node.start,
                () => 'CstFlowPair at ${node.start} does not match YamlMap '
                    'entry',
              ));
          scheduleNode(node.pairValue);
          if (node.colon case final colon?) {
            stack.add(() => indicator(
                colon, YamlTokenKind.value, 'flow key/value separator'));
          } else {
            stack.add(() => checkNoColonEmpty(node.pairValue, 'CstFlowPair'));
          }
          scheduleNode(node.key);
          if (node.questionMark case final questionMark?) {
            stack.add(() => indicator(
                questionMark, YamlTokenKind.key, 'explicit key indicator'));
          }
        case CstFlowCollection():
          check(
            node.start == node.value.span.start.offset,
            node.start,
            () => 'flow collection start ${node.start} does not match YamlNode '
                'span start ${node.value.span.start.offset}',
          );
          final expectedMultiline = document.lineStartOf(node.closeStart) >
              document.lineStartOf(node.contentStart);
          check(
            node.isMultiline == expectedMultiline,
            node.contentStart,
            () => 'flow collection at ${node.start} has '
                'isMultiline=${node.isMultiline}, expected $expectedMultiline',
          );
          indicator(
            node.contentStart,
            node is CstFlowSeq
                ? YamlTokenKind.flowSequenceStart
                : YamlTokenKind.flowMappingStart,
            'flow collection opening delimiter',
          );
          stack.add(() {
            indicator(
              node.closeStart,
              node is CstFlowSeq
                  ? YamlTokenKind.flowSequenceEnd
                  : YamlTokenKind.flowMappingEnd,
              'flow collection closing delimiter',
            );
            check(
              node.end == node.value.span.end.offset,
              node.end,
              () => 'flow collection end ${node.end} does not match YamlNode '
                  'span end ${node.value.span.end.offset}',
            );
            checkContiguousEntries(
              node.openEnd,
              node.entries.length,
              (i) => node.entries[i].start,
              (i) => node.entries[i].end,
              'flow collection',
            );
            if (node is CstFlowSeq) {
              check(
                node.entries.length == node.value.nodes.length,
                node.start,
                () => 'flow sequence has ${node.entries.length} CST entries '
                    'but ${node.value.nodes.length} YamlList elements',
              );
              for (var i = 0; i < node.entries.length; i++) {
                check(
                  identical(node.entries[i].value.value, node.value.nodes[i]),
                  node.entries[i].start,
                  () => 'flow sequence entry $i does not match YamlList '
                      'element',
                );
              }
            } else if (node is CstFlowMap) {
              check(
                node.entries.length == node.value.nodes.length,
                node.start,
                () => 'flow mapping has ${node.entries.length} CST entries but '
                    '${node.value.nodes.length} YamlMap entries',
              );
              var i = 0;
              for (final mapEntry in node.value.nodes.entries) {
                final entry = node.entries[i];
                check(
                  identical(entry.key!.value, mapEntry.key) &&
                      identical(entry.value.value, mapEntry.value),
                  entry.start,
                  () => 'flow mapping entry $i does not match YamlMap entry',
                );
                i++;
              }
            }
          });
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            check(
              i == node.entries.length - 1 || entry.comma != null,
              entry.start,
              () => 'non-final flow entry $i at ${entry.start} is missing a '
                  '"," separator',
            );
            if (node is CstFlowSeq) {
              check(
                entry.key == null &&
                    entry.questionMark == null &&
                    entry.colon == null,
                entry.start,
                () => 'flow sequence entry at ${entry.start} must not have '
                    'key, questionMark, or colon',
              );
            } else {
              check(
                entry.key != null,
                entry.start,
                () => 'flow mapping entry at ${entry.start} must have a key',
              );
            }
            stack.add(() {
              if (entry.comma case final comma?) {
                indicator(
                    comma, YamlTokenKind.flowEntry, 'flow entry separator');
              }
              final expectedEnd =
                  entry.comma != null ? entry.comma! + 1 : entry.value.end;
              check(
                entry.end == expectedEnd,
                entry.end,
                () => 'flow entry ends at ${entry.end}, expected $expectedEnd',
              );
              whitespaceAndComments(entry.end, 'end of flow entry');
            });
            scheduleNode(entry.value, allowFlowPair: node is CstFlowSeq);
            if (entry.key case final key?) {
              if (entry.colon case final colon?) {
                stack.add(() => indicator(
                    colon, YamlTokenKind.value, 'flow key/value separator'));
              } else {
                stack.add(
                    () => checkNoColonEmpty(entry.value, 'flow mapping entry'));
              }
              scheduleNode(key);
            }
            stack.add(() {
              whitespaceAndComments(entry.start, 'flow entry');
              if (entry.questionMark case final questionMark?) {
                indicator(
                  questionMark,
                  YamlTokenKind.key,
                  'explicit key indicator',
                );
              }
            });
          }
      }
    });
  }

  scheduleNode(root);
  while (stack.isNotEmpty) {
    stack.removeLast()();
  }

  check(
    cursor == root.end,
    cursor,
    () => 'root node ended at ${root.end} but cursor is $cursor',
  );
  checkEdgeRegion(root.end, source.length, suffixKinds, 'document suffix');
  check(
    identical(root.value, document.value),
    root.start,
    () => 'root node value does not match document value',
  );
}

/// Renders [text] for an error message, escaping line breaks and truncating.
String _describe(String text) {
  const limit = 40;
  final escaped = text
      .replaceAll('\\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  if (escaped.length <= limit) return '"$escaped"';
  return '"${escaped.substring(0, limit)}"...';
}
