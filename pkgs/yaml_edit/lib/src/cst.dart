// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A concrete syntax tree (CST) for a single YAML document.
///
/// Built from the `YamlNode` value tree and [YamlToken] stream produced by
/// `package:yaml/tokens.dart` (`loadYamlDocumentWithTokens`). Every node,
/// indicator, comment, and whitespace span is recorded with exact character
/// offsets (`[start, end)`).
///
/// ## Tiling model and comment ownership
///
/// A [CstDocument] partitions the source into three contiguous regions:
/// - prefix `[0, root.start)` — directives, `---`, leading blank/comment lines
/// - root `[root.start, root.end)` — the document's syntax tree
/// - suffix `[root.end, source.length)` — `...`, trailing blank/comment lines
///
/// Within block collections, each entry owns `[start, lineStart)` (whole
/// comment and blank lines preceding the entry), `[lineStart, value.end)` (the
/// entry itself), and `[value.end, end)` (trailing spaces, inline comment, and
/// terminating line break on the entry's final line). Deleting `[lineStart,
/// end)` removes the entry and its inline comment while preserving comments
/// written above it.
///
/// [CstDocument.parse] enforces the tiling invariants on every constructed
/// document via [_checkTiling].
library;

import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

/// Thrown when the CST builder cannot produce a valid tiling of a YAML
/// document.
///
/// This indicates an unmodeled document shape or internal builder bug rather
/// than invalid YAML input.
final class CstError extends Error {
  /// Explanation of why CST construction or tiling verification failed.
  final String message;

  /// The character offset in the source at which the problem was detected.
  final int offset;

  CstError(this.message, this.offset);

  @override
  String toString() => 'CstError at $offset: $message';
}

/// A node of the concrete syntax tree.
///
/// Every node occupies the source range `[start, end)`. The range is split into
/// the *properties* `[start, contentStart)` — any leading `&anchor` and/or
/// `!tag` tokens plus intervening whitespace/comments — and the *content*
/// `[contentStart, end)`:
///
/// ```text
/// &anchor !tag scalar_or_collection
/// ^            ^                   ^
/// start        contentStart        contentEnd / end
/// ```
///
/// For a block collection on a new line without properties, [start] and
/// [contentStart] both point to the start of the line holding its first entry
/// (or any leading comment/blank lines preceding that entry). When a block
/// collection has properties on an earlier line, `[start, contentStart)` covers
/// the properties through the end of their line, and [contentStart] starts at
/// the beginning of the following line.
sealed class CstNode {
  /// Offset of the first character of this node, including node properties.
  int get start;

  /// Offset of the first character after this node's properties.
  ///
  /// Equal to [start] when the node has neither an anchor nor a tag.
  int get contentStart;

  /// Offset just past the last character of this node.
  int get end;

  /// Offset just past this node's last piece of *content*.
  ///
  /// For most nodes this is [end]. It differs for block collections, whose
  /// [end] is the end of their last entry and therefore includes the line
  /// break that terminates it. Replacing a node's text must overwrite
  /// `[start, contentEnd)` — using [end] would swallow that line break, and
  /// anything else on the line after it.
  int get contentEnd => end;

  /// The value this node denotes, as parsed by `package:yaml`.
  YamlNode get value;

  /// Whether this node carries an anchor or a tag.
  bool get hasProperties => contentStart != start;
}

/// A scalar written out in the source, in any of YAML's five scalar styles.
///
/// The content range covers exactly the scalar's source text, including any
/// quotes or block scalar header, and excluding any anchor or tag.
final class CstScalar extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;
  @override
  final int end;
  @override
  final YamlScalar value;

  /// The comment token on the header line of a block scalar, if present.
  final YamlToken? headerComment;

  /// The style the scalar is written in.
  ScalarStyle get style => value.style;

  CstScalar({
    required this.start,
    required this.contentStart,
    required this.end,
    required this.value,
    this.headerComment,
  });
}

/// An alias reference, for example `*anchor`.
///
/// Alias nodes share their [value] with the anchored node they refer to, so
/// [value] must never be used to locate this node in the source.
final class CstAlias extends CstNode {
  @override
  final int start;
  @override
  final int end;
  @override
  final YamlNode value;

  @override
  int get contentStart => start;

  CstAlias({required this.start, required this.end, required this.value});
}

/// A node that occupies no source text at all.
///
/// YAML permits a node to be omitted where one is expected, in which case it
/// denotes `null`. Examples are the value of `a:` and the entry of a bare `-`.
///
/// Empty nodes are zero-width: `start == end`. `package:yaml` reports a
/// zero-length span for them, but at an unreliable offset, so the builder
/// positions them structurally instead.
final class CstEmpty extends CstNode {
  @override
  final int start;
  @override
  final YamlScalar value;

  @override
  int get contentStart => start;
  @override
  int get end => start;

  CstEmpty({required this.start, required this.value});
}

/// A sequence written in block style, as a series of `-` entries.
final class CstBlockSeq extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;
  @override
  final YamlList value;

  /// The entries of this sequence, in source order. Never empty: a block
  /// sequence with no entries cannot be written.
  final List<CstBlockSeqEntry> entries;

  /// Whether this sequence starts compactly on the same line as an enclosing
  /// `-` or `?` indicator (for example `- - 1`).
  final bool isCompact;

  @override
  int get end => entries.last.end;

  @override
  int get contentEnd => entries.last.value.contentEnd;

  CstBlockSeq({
    required this.start,
    required this.contentStart,
    required List<CstBlockSeqEntry> entries,
    required this.value,
    required this.isCompact,
  }) : entries = List.unmodifiable(entries);
}

/// One `- value` entry of a [CstBlockSeq].
///
/// The entry tiles as `[start, lineStart)` leading comment and blank lines,
/// `[lineStart, dashStart)` the indentation of the `-`, the `-` itself,
/// `[dashStart + 1, value.start)` separating whitespace and comments, the
/// value, and `[value.end, end)` the trailing part of the value's line:
///
/// ```text
///   # leading comment\n   <-- start
///   - &a value # trailing\n
/// ^ ^ ^        ^           ^
/// | | |        |           +-- end (past line break)
/// | | |        +-- value.end
/// | | +-- value.start
/// | +-- dashStart
/// +-- lineStart
/// ```
final class CstBlockSeqEntry {
  /// Start of this entry's leading comment and blank lines, immediately after
  /// the previous entry.
  final int start;

  /// Start of the line the `-` is written on, or [start] when this is the first
  /// entry of a compact block sequence sharing a line with an outer indicator.
  ///
  /// The range `[start, lineStart)` holds whole lines of blank space and
  /// comments that precede this entry. Deleting an entry deletes
  /// `[lineStart, end)` and leaves those lines in place, so a comment written
  /// above an entry survives the entry's removal.
  final int lineStart;

  /// Offset of the `-` indicator.
  final int dashStart;

  /// The node representing the value of this entry.
  final CstNode value;

  /// End of this entry, just past the line break that terminates it.
  ///
  /// The range `[value.end, end)` holds the remainder of the value's line:
  /// trailing spaces, an optional trailing comment, and the line break. That
  /// trailing comment belongs to this entry and is removed with it.
  final int end;

  /// Whether a comment sits between the `-` indicator and the entry value.
  final bool hasSeparatorComment;

  CstBlockSeqEntry({
    required this.start,
    required this.lineStart,
    required this.dashStart,
    required this.value,
    required this.end,
    required this.hasSeparatorComment,
  });
}

/// A mapping written in block style, as a series of `key: value` entries.
final class CstBlockMap extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;
  @override
  final YamlMap value;

  /// The entries of this mapping, in source order. Never empty: a block
  /// mapping with no entries cannot be written.
  final List<CstBlockMapEntry> entries;

  /// Whether this mapping starts compactly on the same line as an enclosing
  /// `-` or `?` indicator (for example `- a: 1`).
  final bool isCompact;

  @override
  int get end => entries.last.end;

  @override
  int get contentEnd => entries.last.value.contentEnd;

  CstBlockMap({
    required this.start,
    required this.contentStart,
    required List<CstBlockMapEntry> entries,
    required this.value,
    required this.isCompact,
  }) : entries = List.unmodifiable(entries);
}

/// One `key: value` entry of a [CstBlockMap].
///
/// ```text
///   # leading comment\n   <-- start
///   ? key : value # comment\n
/// ^ ^ ^   ^ ^     ^          ^
/// | | |   | |     |          +-- end (past line break)
/// | | |   | |     +-- value.end
/// | | |   | +-- value.start
/// | | |   +-- colon
/// | | +-- key.start
/// | +-- questionMark (optional; keyStart == questionMark ?? key.start)
/// +-- lineStart
/// ```
final class CstBlockMapEntry {
  /// Start of this entry's leading comment and blank lines, immediately after
  /// the previous entry.
  final int start;

  /// Start of the line the key is written on, or [start] when this is the first
  /// entry of a compact block mapping sharing a line with an outer indicator.
  final int lineStart;

  /// Offset of the `?` indicator, for entries written in explicit key form.
  final int? questionMark;

  /// The node representing the key of this entry.
  final CstNode key;

  /// Offset of the `:` separating key from value.
  ///
  /// `null` for an explicit-key entry written without a value, as in `? a`.
  final int? colon;

  /// The node representing the value of this entry.
  final CstNode value;

  /// End of this entry, just past the line break that terminates it.
  final int end;

  /// Whether a comment sits between the `:` separator and the entry value.
  final bool hasSeparatorComment;

  /// Offset of the first character of this entry's own content, which is the
  /// `?` if there is one and the key otherwise.
  int get keyStart => questionMark ?? key.start;

  CstBlockMapEntry({
    required this.start,
    required this.lineStart,
    required this.questionMark,
    required this.key,
    required this.colon,
    required this.value,
    required this.end,
    required this.hasSeparatorComment,
  });
}

/// A collection written in flow style, as `[...]` or `{...}`.
///
/// ```text
/// &anchor [  entry0,  entry1  ]
/// ^       ^^                  ^^
/// |       ||                  |+-- end
/// |       ||                  +-- closeStart (trailing trivia ends here)
/// |       |+-- openEnd (== entries.first.start when non-empty)
/// |       +-- contentStart
/// +-- start
/// ```
sealed class CstFlowCollection extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;

  /// The entries of this collection, in source order. May be empty.
  final List<CstFlowEntry> entries;

  /// Offset of the closing `]` or `}`.
  final int closeStart;

  /// Whether the flow collection spans multiple lines.
  final bool isMultiline;

  CstFlowCollection({
    required this.start,
    required this.contentStart,
    required List<CstFlowEntry> entries,
    required this.closeStart,
    required this.isMultiline,
  }) : entries = List.unmodifiable(entries);

  /// Offset just past the opening `[` or `{`.
  int get openEnd => contentStart + 1;

  @override
  int get end => closeStart + 1;

  /// Start of the whitespace and comments preceding the closing delimiter.
  int get beforeCloseStart => entries.isEmpty ? openEnd : entries.last.end;
}

/// A sequence written as `[a, b]`.
final class CstFlowSeq extends CstFlowCollection {
  @override
  final YamlList value;

  CstFlowSeq({
    required super.start,
    required super.contentStart,
    required super.entries,
    required super.closeStart,
    required super.isMultiline,
    required this.value,
  });
}

/// A mapping written as `{a: 1, b: 2}`.
final class CstFlowMap extends CstFlowCollection {
  @override
  final YamlMap value;

  CstFlowMap({
    required super.start,
    required super.contentStart,
    required super.entries,
    required super.closeStart,
    required super.isMultiline,
    required this.value,
  });
}

/// One entry of a [CstFlowCollection].
///
/// The entry tiles as leading whitespace and comments, an optional `?`, the key
/// and `:` if this is a mapping entry, the value, then trailing whitespace and
/// comments and an optional `,`:
///
/// ```text
///   ? key : value ,
/// ^ ^ ^   ^ ^     ^^
/// | | |   | |     |+-- end (comma + 1, or value.end when comma == null)
/// | | |   | |     +-- comma (optional)
/// | | |   | +-- value.start
/// | | |   +-- colon (optional)
/// | | +-- key.start (optional)
/// | +-- contentStart (questionMark ?? key?.start ?? value.start)
/// +-- start (leading trivia after `[` / `{` or previous `,`)
/// ```
final class CstFlowEntry {
  /// Start of this entry's leading whitespace and comments, immediately after
  /// the opening delimiter or the previous entry.
  final int start;

  /// Offset of the `?` indicator, for entries written in explicit key form.
  final int? questionMark;

  /// The key, for entries of a [CstFlowMap]. `null` for sequence entries.
  final CstNode? key;

  /// Offset of the `:` separating key from value, if present.
  final int? colon;

  /// The value node of this flow entry.
  final CstNode value;

  /// Offset of the `,` terminating this entry, if present.
  ///
  /// `null` for the final entry of a collection written without a trailing
  /// comma.
  final int? comma;

  /// End of this entry: `comma + 1` if a comma is present, otherwise
  /// `value.end`.
  final int end;

  CstFlowEntry({
    required this.start,
    required this.questionMark,
    required this.key,
    required this.colon,
    required this.value,
    required this.comma,
    required this.end,
  });

  /// Offset of the first character of this entry's own content.
  int get contentStart => questionMark ?? key?.start ?? value.start;
}

/// A single-pair mapping written inside a flow sequence without braces.
///
/// YAML allows one `key: value` pair to stand in for a mapping where a flow
/// sequence entry is expected, so `[a: 1]` is a sequence holding the mapping
/// `{a: 1}`. There is no `{` or `}` to anchor to, so this needs its own node
/// type rather than being a [CstFlowMap] with absent delimiters.
///
/// See [7.20 Single Pair Explicit Entry](https://yaml.org/spec/1.2.2/#rule-c-s-implicit-json-key).
final class CstFlowPair extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;
  @override
  final YamlMap value;

  /// Offset of the `?` indicator, for pairs written in explicit key form.
  final int? questionMark;

  /// The key node of the pair.
  final CstNode key;

  /// Offset of the `:` separating key from value, if present.
  final int? colon;

  /// The value node of the pair.
  final CstNode pairValue;

  @override
  int get end => pairValue.end;

  CstFlowPair({
    required this.start,
    required this.contentStart,
    required this.questionMark,
    required this.key,
    required this.colon,
    required this.pairValue,
    required this.value,
  });
}

/// Precomputed line metadata for fast structural queries without rescanning.
final class _LineTable {
  final List<int> lineStarts;
  final List<int> lineContentEnds;
  final List<int> lineBreakEnds;
  final String lineEnding;

  _LineTable._({
    required this.lineStarts,
    required this.lineContentEnds,
    required this.lineBreakEnds,
    required this.lineEnding,
  });

  factory _LineTable(String source) {
    final starts = <int>[0];
    final contentEnds = <int>[];
    final breakEnds = <int>[];
    var unixNewlines = 0;
    var windowsNewlines = 0;

    var index = 0;
    final length = source.length;
    while (index < length) {
      final char = source[index];
      if (char == '\r') {
        contentEnds.add(index);
        if (index + 1 < length && source[index + 1] == '\n') {
          windowsNewlines++;
          index += 2;
        } else {
          index += 1;
        }
        breakEnds.add(index);
        starts.add(index);
      } else if (char == '\n') {
        contentEnds.add(index);
        unixNewlines++;
        index += 1;
        breakEnds.add(index);
        starts.add(index);
      } else {
        index++;
      }
    }

    contentEnds.add(length);
    breakEnds.add(length);

    return _LineTable._(
      lineStarts: List.unmodifiable(starts),
      lineContentEnds: List.unmodifiable(contentEnds),
      lineBreakEnds: List.unmodifiable(breakEnds),
      lineEnding: windowsNewlines > unixNewlines ? '\r\n' : '\n',
    );
  }

  /// Finds the 0-based line index for [offset].
  int lineIndexFor(int offset) {
    if (offset <= 0) return 0;
    final lastIndex = lineStarts.length - 1;
    if (offset >= lineStarts[lastIndex]) return lastIndex;

    var low = 0;
    var high = lastIndex;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = lineStarts[mid];
      if (start == offset) return mid;
      if (start < offset) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return high;
  }

  /// Start offset of the line containing [offset].
  int lineStartOf(int offset) => lineStarts[lineIndexFor(offset)];

  /// End of content (before line break) of the line containing [offset].
  int lineContentEndOf(int offset) => lineContentEnds[lineIndexFor(offset)];

  /// Offset just past the line break of the line containing [offset].
  int lineBreakEndOf(int offset) => lineBreakEnds[lineIndexFor(offset)];

  /// Zero-based column of [offset] relative to the start of its line.
  int columnOf(int offset) => offset - lineStartOf(offset);
}

/// A parsed YAML document, tiled into a prefix, a root node and a suffix.
///
/// The prefix holds anything preceding the root node — directives, a `---`
/// marker, leading comments and blank lines. The suffix holds anything
/// following it, such as a `...` marker and trailing comments.
final class CstDocument {
  /// The source this document was parsed from.
  final String source;

  /// The root node, or `null` for a document that contains no node at all.
  ///
  /// An empty document — one that is blank or holds nothing but comments —
  /// still denotes `null`, but has no node to attach layout to, so the whole
  /// source is the prefix.
  final CstNode? root;

  /// Offset at which the root node starts. Equals `source.length` when [root]
  /// is `null`.
  int get prefixEnd => root?.start ?? source.length;

  /// Offset at which the suffix starts.
  int get suffixStart => root?.end ?? source.length;

  /// The value of the document, which is `null` for an empty document.
  final YamlNode value;

  /// All tokens retained during parsing, ordered by ascending start offset.
  final List<YamlToken> tokens;

  /// All comment tokens retained during parsing, ordered by ascending start
  /// offset.
  final List<YamlToken> comments;

  /// The primary line terminator detected in this document (majority vote of
  /// `\r\n` vs `\n`, defaulting to `\n`).
  final String lineEnding;

  final _LineTable _lineTable;

  CstDocument._({
    required this.source,
    required this.root,
    required this.value,
    required List<YamlToken> tokens,
    required List<YamlToken> comments,
    required this.lineEnding,
    required _LineTable lineTable,
  })  : tokens = List.unmodifiable(tokens),
        comments = List.unmodifiable(comments),
        _lineTable = lineTable;

  /// Returns the offset of the first character of the line containing [offset].
  int lineStartOf(int offset) => _lineTable.lineStartOf(offset);

  /// Returns the offset just before the line break terminating the line
  /// containing [offset], or `source.length` if the line has no line break.
  int lineContentEndOf(int offset) => _lineTable.lineContentEndOf(offset);

  /// Returns the offset just past the line break terminating the line
  /// containing [offset], or `source.length` if the line has no line break.
  int lineBreakEndOf(int offset) => _lineTable.lineBreakEndOf(offset);

  /// Zero-based column index of [offset] relative to the start of its line.
  int columnOf(int offset) => _lineTable.columnOf(offset);

  /// Binary search for the first index in [comments] with start >= [offset].
  int _firstCommentIndexAtOrAfter(int offset) {
    var low = 0;
    var high = comments.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (comments[mid].span.start.offset < offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Returns the first comment token fully contained in `[start, end)`, or
  /// `null` if none exists.
  YamlToken? commentInRange(int start, int end) {
    if (start >= end) return null;
    for (var i = _firstCommentIndexAtOrAfter(start); i < comments.length; i++) {
      final comment = comments[i];
      if (comment.span.start.offset >= end) break;
      if (comment.span.end.offset <= end) return comment;
    }
    return null;
  }

  /// Returns all comment tokens fully contained in `[start, end)`.
  List<YamlToken> commentsInRange(int start, int end) {
    if (start >= end) return const [];
    final result = <YamlToken>[];
    for (var i = _firstCommentIndexAtOrAfter(start); i < comments.length; i++) {
      final comment = comments[i];
      if (comment.span.start.offset >= end) break;
      if (comment.span.end.offset <= end) result.add(comment);
    }
    return result;
  }

  /// Parses [source] into a CST.
  ///
  /// Throws a [YamlException] if [source] is not a valid YAML document, and a
  /// [CstError] if it is valid but the builder cannot tile it.
  factory CstDocument.parse(String source) {
    final (:document, :tokens) = loadYamlDocumentWithTokens(source);
    final value = document.contents;
    final lineTable = _LineTable(source);
    final tokensByOffset = <int, YamlToken>{
      for (final token in tokens) token.span.start.offset: token,
    };
    final builder = _CstBuilder(source, tokensByOffset, lineTable);
    final root = builder.buildDocument(value);
    final comments = [
      for (final token in tokens)
        if (token.kind == YamlTokenKind.comment) token,
    ];
    final cst = CstDocument._(
      source: source,
      root: root,
      value: value,
      tokens: tokens,
      comments: comments,
      lineEnding: lineTable.lineEnding,
      lineTable: lineTable,
    );
    _checkTiling(cst, tokensByOffset);
    return cst;
  }
}

// ---------------------------------------------------------------------------
// Tiling check
// ---------------------------------------------------------------------------

/// Verifies that [document]'s slots tile its source accurately.
///
/// Walks the tree iteratively in source order and checks that:
/// 1. The prefix `[0, prefixEnd)` holds only whitespace, BOM, comments,
///    directives, and document markers (`---`/`...`).
/// 2. The suffix `[suffixStart, source.length)` holds only whitespace, BOM,
///    comments, and document end markers (`...`).
/// 3. Slot boundaries are monotonically non-decreasing (disjoint and ordered).
/// 4. Every structural indicator (`-`, `?`, `:`, `,`, `[`, `]`, `{`, `}`)
///    matches its expected character in the source.
/// 5. Every gap between slots holds only whitespace and whole
///    [YamlTokenKind.comment] tokens.
/// 6. Node property regions `[start, contentStart)` hold only whitespace,
///    comments, anchors, and tags.
/// 7. Every [CstScalar] matches its [YamlScalar.span] and every [CstAlias]
///    matches an earlier-targeted [YamlTokenKind.alias] token.
///
/// Throws a [CstError] if any check fails.
void _checkTiling(CstDocument document, Map<int, YamlToken> tokensByOffset) {
  final source = document.source;
  var cursor = 0;

  bool isTriviaChar(int codeUnit) =>
      codeUnit == 0x20 || // space
      codeUnit == 0x09 || // tab
      codeUnit == 0x0A || // LF
      codeUnit == 0x0D; // CR

  /// Checks a prefix or suffix region where only whitespace, BOM, and tokens
  /// of [allowedKinds] may appear.
  void checkEdgeRegion(
    int start,
    int end,
    Set<YamlTokenKind> allowedKinds,
    String what,
  ) {
    if (end < start || end > source.length) {
      throw CstError('$what bounds [$start, $end) out of range', start);
    }
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
    if (offset < cursor) {
      throw CstError(
        'slot "$what" starts at $offset, before the previous slot ended at '
        '$cursor',
        offset,
      );
    }
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

  /// Advances the cursor over `[cursor, offset)` requiring only whitespace,
  /// comments, anchors, and tags.
  void properties(int offset) {
    if (offset < cursor) {
      throw CstError(
        'node properties end at $offset, before they started at $cursor',
        offset,
      );
    }
    var index = cursor;
    while (index < offset) {
      if (isTriviaChar(source.codeUnitAt(index))) {
        index++;
      } else if (tokensByOffset[index] case final token?
          when (token.kind == YamlTokenKind.anchor ||
                  token.kind == YamlTokenKind.tag ||
                  token.kind == YamlTokenKind.comment) &&
              token.span.end.offset <= offset) {
        index = token.span.end.offset;
      } else {
        throw CstError(
          'unexpected token in node properties: '
          '${_describe(source.substring(cursor, offset))}',
          index,
        );
      }
    }
    cursor = offset;
  }

  /// Advances the cursor past an indicator that must be [char].
  void indicator(int offset, String char, String what) {
    whitespaceAndComments(offset, what);
    if (offset >= source.length || source[offset] != char) {
      final found = offset >= source.length
          ? '<end of input>'
          : _describe(source[offset]);
      throw CstError(
        'expected $what ("$char") at $offset but found $found',
        offset,
      );
    }
    cursor = offset + 1;
  }

  /// Advances the cursor over a scalar or alias body.
  void opaque(int offset, String what) {
    if (offset < cursor) {
      throw CstError(
        'slot "$what" ends at $offset, before it started at $cursor',
        offset,
      );
    }
    cursor = offset;
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

  void scheduleNode(CstNode node) {
    stack.add(() {
      whitespaceAndComments(node.start, 'node');
      properties(node.contentStart);
      switch (node) {
        case CstScalar():
          if (node.start != node.value.span.start.offset ||
              node.end != node.value.span.end.offset) {
            throw CstError(
              'scalar slot [${node.start}, ${node.end}) does not match '
              'YamlScalar span [${node.value.span.start.offset}, '
              '${node.value.span.end.offset})',
              node.start,
            );
          }
          opaque(node.end, 'scalar');
        case CstAlias():
          final aliasToken = tokensByOffset[node.start];
          if (aliasToken == null ||
              aliasToken.kind != YamlTokenKind.alias ||
              aliasToken.span.end.offset != node.end) {
            throw CstError(
              'alias slot [${node.start}, ${node.end}) does not match an alias '
              'token',
              node.start,
            );
          }
          if (node.value.span.start.offset >= node.start) {
            throw CstError(
              'alias at ${node.start} points to node starting at '
              '${node.value.span.start.offset}',
              node.start,
            );
          }
          opaque(node.end, 'alias');
        case CstEmpty():
          opaque(node.end, 'empty');
        case CstBlockSeq():
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            stack.add(() =>
                whitespaceAndComments(entry.end, 'end of block seq entry'));
            scheduleNode(entry.value);
            stack.add(() {
              whitespaceAndComments(entry.start, 'block sequence entry');
              whitespaceAndComments(
                  entry.lineStart, 'block sequence entry line');
              indicator(entry.dashStart, '-', 'block sequence entry indicator');
            });
          }
        case CstBlockMap():
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            stack.add(() =>
                whitespaceAndComments(entry.end, 'end of block map entry'));
            scheduleNode(entry.value);
            if (entry.colon case final colon?) {
              stack.add(() => indicator(colon, ':', 'key/value separator'));
            }
            scheduleNode(entry.key);
            stack.add(() {
              whitespaceAndComments(entry.start, 'block mapping entry');
              whitespaceAndComments(
                  entry.lineStart, 'block mapping entry line');
              if (entry.questionMark case final questionMark?) {
                indicator(questionMark, '?', 'explicit key indicator');
              }
            });
          }
        case CstFlowPair():
          scheduleNode(node.pairValue);
          if (node.colon case final colon?) {
            stack.add(() => indicator(colon, ':', 'flow key/value separator'));
          }
          scheduleNode(node.key);
          if (node.questionMark case final questionMark?) {
            stack.add(
                () => indicator(questionMark, '?', 'explicit key indicator'));
          }
        case CstFlowCollection():
          indicator(
            node.contentStart,
            node is CstFlowSeq ? '[' : '{',
            'flow collection opening delimiter',
          );
          stack.add(() => indicator(
                node.closeStart,
                node is CstFlowSeq ? ']' : '}',
                'flow collection closing delimiter',
              ));
          for (var i = node.entries.length - 1; i >= 0; i--) {
            final entry = node.entries[i];
            stack.add(() {
              if (entry.comma case final comma?) {
                indicator(comma, ',', 'flow entry separator');
              }
              whitespaceAndComments(entry.end, 'end of flow entry');
            });
            scheduleNode(entry.value);
            if (entry.key case final key?) {
              if (entry.colon case final colon?) {
                stack.add(
                    () => indicator(colon, ':', 'flow key/value separator'));
              }
              scheduleNode(key);
            }
            stack.add(() {
              whitespaceAndComments(entry.start, 'flow entry');
              if (entry.questionMark case final questionMark?) {
                indicator(questionMark, '?', 'explicit key indicator');
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

  if (cursor != root.end) {
    throw CstError(
        'root node ended at ${root.end} but cursor is $cursor', cursor);
  }
  checkEdgeRegion(root.end, source.length, suffixKinds, 'document suffix');
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

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/// Builds a CST by advancing through the source under the guidance of the value
/// tree and the token stream emitted by `package:yaml/tokens.dart`.
final class _CstBuilder {
  final String source;
  final Map<int, YamlToken> _tokensByOffset;
  final _LineTable _lineTable;
  int position = 0;

  _CstBuilder(this.source, this._tokensByOffset, this._lineTable);

  int get length => source.length;

  bool get atEnd => position >= length;

  bool _isSpace(int offset) =>
      offset < length && (source[offset] == ' ' || source[offset] == '\t');

  bool _isBreak(int offset) =>
      offset < length && (source[offset] == '\n' || source[offset] == '\r');

  /// Returns the offset just past the line break starting at [offset].
  int _pastBreak(int offset) {
    if (source[offset] == '\r' &&
        offset + 1 < length &&
        source[offset + 1] == '\n') {
      return offset + 2;
    }
    return offset + 1;
  }

  /// Advances past spaces and tabs.
  void _skipSpaces() {
    while (_isSpace(position)) {
      position++;
    }
  }

  /// Advances past spaces, tabs, line breaks, and comments.
  void _skipWhitespaceAndComments() {
    while (!atEnd) {
      if (_isSpace(position)) {
        position++;
      } else if (_tokensByOffset[position] case final token?
          when token.kind == YamlTokenKind.comment) {
        position = token.span.end.offset;
      } else if (_isBreak(position)) {
        position = _pastBreak(position);
      } else {
        return;
      }
    }
  }

  /// Advances past whole lines that contain nothing but blank space and
  /// comments, returning the offset at which the first line with content
  /// begins (or [position] unchanged when called mid-line on a compact entry).
  int _skipCommentAndBlankLines() {
    while (true) {
      var probe = position;
      while (_isSpace(probe)) {
        probe++;
      }
      if (_tokensByOffset[probe] case final token?
          when token.kind == YamlTokenKind.comment) {
        probe = token.span.end.offset;
      }
      if (probe < length && _isBreak(probe)) {
        position = _pastBreak(probe);
        continue;
      }
      return position;
    }
  }

  /// Consumes the remainder of the current line if it holds nothing but blank
  /// space and an optional comment, returning the resulting position.
  int _consumeTrailingLine() {
    var probe = position;
    while (_isSpace(probe)) {
      probe++;
    }
    if (_tokensByOffset[probe] case final token?
        when token.kind == YamlTokenKind.comment) {
      probe = token.span.end.offset;
    }
    if (probe >= length) {
      position = probe;
    } else if (_isBreak(probe)) {
      position = _pastBreak(probe);
    }
    return position;
  }

  Never _fail(String message) => throw CstError(message, position);

  void _expectToken(YamlTokenKind expectedKind, String what) {
    final token = _tokensByOffset[position];
    if (token == null || token.kind != expectedKind) {
      final found =
          token?.kind ?? (atEnd ? '<end of input>' : '"${source[position]}"');
      _fail('expected $what ($expectedKind) but found $found');
    }
    position = token.span.end.offset;
  }

  int? _tryConsumeToken(YamlTokenKind kind) {
    final token = _tokensByOffset[position];
    if (token != null && token.kind == kind) {
      final start = position;
      position = token.span.end.offset;
      return start;
    }
    return null;
  }

  bool _hasCommentBetween(int start, int end) {
    for (var offset = start; offset < end; offset++) {
      if (_tokensByOffset[offset]?.kind == YamlTokenKind.comment) {
        return true;
      }
    }
    return false;
  }

  /// Whether [node] is written as nothing at all.
  static bool _isEmptyNode(YamlNode node) =>
      node is YamlScalar && node.span.length == 0;

  /// Builds the root node, leaving [position] just past it.
  CstNode? buildDocument(YamlNode value) {
    // A document with no node at all still parses as `null`, with style ANY.
    if (value is YamlScalar &&
        value.style == ScalarStyle.ANY &&
        value.value == null) {
      return null;
    }
    position = value.span.start.offset;
    return _buildNode(value);
  }

  /// Builds the node [value], which must start at [position].
  CstNode _buildNode(YamlNode value) {
    final start = position;

    // Aliases share their value — and therefore their span — with the earlier
    // anchored node they refer to. Guard with `value.span.start.offset <
    // position` so a compact block mapping whose first key is an alias
    // (`- *a : v`) is not mistaken for an alias itself.
    if (_tokensByOffset[position] case final token?
        when token.kind == YamlTokenKind.alias &&
            value.span.start.offset < position) {
      position = token.span.end.offset;
      return CstAlias(start: start, end: position, value: value);
    }

    if (_isEmptyNode(value)) {
      return CstEmpty(start: start, value: value as YamlScalar);
    }

    switch (value) {
      case YamlScalar():
        // Bound by `value.span.end.offset` so property-only scalars like
        // `a: &anchor` do not consume past themselves.
        _skipProperties(limit: value.span.end.offset);
        return _buildScalar(start, position, value);

      case YamlList() when value.style == CollectionStyle.FLOW:
        _skipProperties(landsOn: YamlTokenKind.flowSequenceStart);
        return _buildFlowCollection(start, position, value);

      case YamlList():
        _skipProperties(crossesLineBreak: true);
        return _buildBlockSeq(start, position, value);

      case YamlMap() when value.style != CollectionStyle.FLOW:
        final firstKey = value.nodes.keys.firstOrNull as YamlNode?;
        final bound = firstKey != null && firstKey.span.start.offset >= position
            ? firstKey.span.start.offset
            : null;
        _skipProperties(crossesLineBreak: true, bound: bound);
        return _buildBlockMap(start, position, value);

      case YamlMap():
        if (_isBraced(value)) {
          _skipProperties(landsOn: YamlTokenKind.flowMappingStart);
          return _buildFlowCollection(start, position, value);
        }
        // A flow mapping written without braces is a single pair standing in
        // for a mapping inside a flow sequence, as in `[a: 1]`. Any anchor or
        // tag at `position` belongs to its key rather than to the pair.
        return _buildFlowPair(start, position, value);

      default:
        _fail('unsupported node type ${value.runtimeType}');
    }
  }

  /// Whether the flow mapping [value] is written with `{...}` braces.
  bool _isBraced(YamlMap value) {
    // A single-pair flow mapping has no braces of its own; its sole key starts
    // right at `position` (unless preceded by `?` or an empty implicit key `:`,
    // in which case `position` is not `{` or a property anyway).
    if (value.nodes.length == 1) {
      final firstKey = value.nodes.keys.single as YamlNode;
      if (firstKey.span.start.offset == position) return false;
    }
    final saved = position;
    _skipProperties(landsOn: YamlTokenKind.flowMappingStart);
    final startToken = _tokensByOffset[position];
    position = saved;
    final end = value.span.end.offset;
    final endToken = end > 0 ? _tokensByOffset[end - 1] : null;
    return startToken?.kind == YamlTokenKind.flowMappingStart &&
        endToken?.kind == YamlTokenKind.flowMappingEnd;
  }

  /// Consumes any anchor and tag tokens written before a node's content, along
  /// with separating whitespace and comments, if doing so satisfies the
  /// required acceptance condition.
  ///
  /// When [crossesLineBreak] is `true` (block collections), rewinds to the
  /// start of the line immediately after the last property's line break so the
  /// first entry retains its own leading indentation and comment lines.
  void _skipProperties({
    int? limit,
    int? bound,
    YamlTokenKind? landsOn,
    bool crossesLineBreak = false,
  }) {
    assert(
      [limit, landsOn, crossesLineBreak ? true : null].nonNulls.length == 1,
      'exactly one acceptance condition must be given',
    );
    final maxOffset =
        limit ?? (bound != null && bound >= position ? bound : null) ?? length;
    final start = position;
    var sawBreak = false;
    int? lineStartAfterLastProperty;

    while (position < maxOffset) {
      final token = _tokensByOffset[position];
      if (token == null ||
          (token.kind != YamlTokenKind.anchor &&
              token.kind != YamlTokenKind.tag)) {
        break;
      }
      if (token.span.end.offset > maxOffset) break;

      position = token.span.end.offset;
      int? firstBreakAfterThisProperty;
      while (position < maxOffset) {
        if (_isBreak(position)) {
          sawBreak = true;
          position = _pastBreak(position);
          firstBreakAfterThisProperty ??= position;
        } else if (_isSpace(position)) {
          position++;
        } else if (_tokensByOffset[position] case final comment?
            when comment.kind == YamlTokenKind.comment) {
          position = comment.span.end.offset;
        } else {
          break;
        }
      }
      lineStartAfterLastProperty = firstBreakAfterThisProperty;
    }

    if (position == start) return;
    final bool accepted;
    if (limit != null) {
      accepted = true;
    } else if (landsOn != null) {
      accepted = _tokensByOffset[position]?.kind == landsOn;
    } else {
      accepted = sawBreak;
      if (accepted && lineStartAfterLastProperty != null) {
        position = lineStartAfterLastProperty;
      }
    }
    if (!accepted) position = start;
  }

  CstNode _buildScalar(int start, int contentStart, YamlScalar value) {
    final end = value.span.end.offset;
    YamlToken? headerComment;

    if (value.style == ScalarStyle.LITERAL ||
        value.style == ScalarStyle.FOLDED) {
      final headerLineBreak = _lineTable.lineBreakEndOf(contentStart);
      for (var offset = contentStart + 1; offset < headerLineBreak; offset++) {
        if (_tokensByOffset[offset] case final token?
            when token.kind == YamlTokenKind.comment) {
          headerComment = token;
          break;
        }
      }
    }

    if (end < contentStart) {
      _fail('scalar ends before it starts');
    }
    position = end;
    return CstScalar(
      start: start,
      contentStart: contentStart,
      end: end,
      value: value,
      headerComment: headerComment,
    );
  }

  /// Advances to and builds the child node of a block sequence or mapping
  /// entry.
  CstNode _buildBlockChild(YamlNode child) {
    if (_isEmptyNode(child)) {
      return CstEmpty(start: position, value: child as YamlScalar);
    }
    final isBlock = (child is YamlMap && child.style != CollectionStyle.FLOW) ||
        (child is YamlList && child.style != CollectionStyle.FLOW);
    final firstChildKind = _tokensByOffset[child.span.start.offset]?.kind;
    final hasProperties = firstChildKind == YamlTokenKind.anchor ||
        firstChildKind == YamlTokenKind.tag;
    if (isBlock &&
        !hasProperties &&
        _lineTable.lineStartOf(child.span.start.offset) >
            _lineTable.lineStartOf(position)) {
      _consumeTrailingLine();
    } else {
      _skipWhitespaceAndComments();
    }
    return _buildNode(child);
  }

  /// Attempts to consume a `:` value indicator after a mapping key.
  ///
  /// When [expectedColumnOnNewLine] is provided (block mappings), a `:` on a
  /// later line than [keyEnd] is only accepted if its column matches
  /// [expectedColumnOnNewLine] so an inner explicit key cannot steal an outer
  /// mapping's `:`.
  int? _tryConsumeColon({required int keyEnd, int? expectedColumnOnNewLine}) {
    final beforeColon = position;
    _skipWhitespaceAndComments();
    var colon = _tryConsumeToken(YamlTokenKind.value);
    if (colon != null &&
        expectedColumnOnNewLine != null &&
        _lineTable.lineStartOf(colon) > _lineTable.lineStartOf(keyEnd) &&
        _lineTable.columnOf(colon) != expectedColumnOnNewLine) {
      colon = null;
    }
    if (colon == null) {
      position = beforeColon;
    }
    return colon;
  }

  CstBlockSeq _buildBlockSeq(int start, int contentStart, YamlList value) {
    final isCompact = contentStart > _lineTable.lineStartOf(contentStart);
    final entries = <CstBlockSeqEntry>[];
    for (final child in value.nodes) {
      final entryStart = position;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();
      final dashStart = position;
      _expectToken(YamlTokenKind.blockEntry, 'block sequence entry indicator');

      final childNode = _buildBlockChild(child);

      entries.add(CstBlockSeqEntry(
        start: entryStart,
        lineStart: lineStart,
        dashStart: dashStart,
        value: childNode,
        hasSeparatorComment: _hasCommentBetween(dashStart + 1, childNode.start),
        end: childNode is CstBlockSeq || childNode is CstBlockMap
            ? childNode.end
            : _consumeTrailingLine(),
      ));
    }
    if (entries.isEmpty) {
      _fail('block sequence with no entries');
    }
    return CstBlockSeq(
      start: start,
      contentStart: contentStart,
      entries: entries,
      value: value,
      isCompact: isCompact,
    );
  }

  CstBlockMap _buildBlockMap(int start, int contentStart, YamlMap value) {
    final isCompact = contentStart > _lineTable.lineStartOf(contentStart);
    final entries = <CstBlockMapEntry>[];
    value.nodes.forEach((key, child) {
      final entryStart = position;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();

      final questionMark = _tryConsumeToken(YamlTokenKind.key);
      if (questionMark != null) {
        _skipWhitespaceAndComments();
      }

      final keyValue = key as YamlNode;
      final keyNode = _isEmptyNode(keyValue)
          ? CstEmpty(start: position, value: keyValue as YamlScalar)
          : _buildNode(keyValue);

      final entryColumn = _lineTable.columnOf(questionMark ?? keyNode.start);
      final colon = _tryConsumeColon(
        keyEnd: keyNode.end,
        expectedColumnOnNewLine: entryColumn,
      );

      final valueNode = _buildBlockChild(child);

      entries.add(CstBlockMapEntry(
        start: entryStart,
        lineStart: lineStart,
        questionMark: questionMark,
        key: keyNode,
        colon: colon,
        value: valueNode,
        hasSeparatorComment:
            colon != null && _hasCommentBetween(colon + 1, valueNode.start),
        end: valueNode is CstBlockSeq || valueNode is CstBlockMap
            ? valueNode.end
            : _consumeTrailingLine(),
      ));
    });
    if (entries.isEmpty) {
      _fail('block mapping with no entries');
    }
    return CstBlockMap(
      start: start,
      contentStart: contentStart,
      entries: entries,
      value: value,
      isCompact: isCompact,
    );
  }

  /// Builds a [CstFlowSeq] or [CstFlowMap].
  ///
  /// Entry parsing is kept inline here so each nesting level uses only two Dart
  /// stack frames (`_buildNode` -> `_buildFlowCollection`), matching
  /// `package:yaml`'s loader depth.
  CstFlowCollection _buildFlowCollection(
    int start,
    int contentStart,
    YamlNode value,
  ) {
    final isSeq = value is YamlList;
    _expectToken(
      isSeq ? YamlTokenKind.flowSequenceStart : YamlTokenKind.flowMappingStart,
      isSeq
          ? 'flow sequence opening delimiter'
          : 'flow mapping opening delimiter',
    );

    final entries = <CstFlowEntry>[];
    void addEntry(YamlNode? key, YamlNode child) {
      final entryStart = position;
      _skipWhitespaceAndComments();

      int? questionMark;
      CstNode? keyNode;
      int? colon;
      if (key != null) {
        (:questionMark, key: keyNode, :colon) = _buildFlowKey(key);
      }

      final CstNode valueNode;
      if (_isEmptyNode(child)) {
        valueNode = CstEmpty(start: position, value: child as YamlScalar);
      } else {
        _skipWhitespaceAndComments();
        valueNode = _buildNode(child);
      }

      final afterValue = position;
      _skipWhitespaceAndComments();
      final comma = _tryConsumeToken(YamlTokenKind.flowEntry);
      if (comma == null) {
        position = afterValue;
      }

      entries.add(CstFlowEntry(
        start: entryStart,
        questionMark: questionMark,
        key: keyNode,
        colon: colon,
        value: valueNode,
        comma: comma,
        end: position,
      ));
    }

    if (value is YamlList) {
      for (final child in value.nodes) {
        addEntry(null, child);
      }
    } else {
      (value as YamlMap).nodes.forEach((key, child) {
        addEntry(key as YamlNode, child);
      });
    }

    _skipWhitespaceAndComments();
    final closeStart = position;
    _expectToken(
      isSeq ? YamlTokenKind.flowSequenceEnd : YamlTokenKind.flowMappingEnd,
      isSeq
          ? 'flow sequence closing delimiter'
          : 'flow mapping closing delimiter',
    );
    final isMultiline = _lineTable.lineStartOf(closeStart) >
        _lineTable.lineStartOf(contentStart);

    if (value is YamlList) {
      return CstFlowSeq(
        start: start,
        contentStart: contentStart,
        entries: entries,
        closeStart: closeStart,
        isMultiline: isMultiline,
        value: value,
      );
    }
    return CstFlowMap(
      start: start,
      contentStart: contentStart,
      entries: entries,
      closeStart: closeStart,
      isMultiline: isMultiline,
      value: value as YamlMap,
    );
  }

  CstFlowPair _buildFlowPair(int start, int contentStart, YamlMap value) {
    if (value.nodes.length != 1) {
      _fail(
        'a flow mapping written without braces must hold exactly one pair, '
        'but this one holds ${value.nodes.length}',
      );
    }
    final key = value.nodes.keys.single as YamlNode;
    final (:questionMark, key: keyNode, :colon) = _buildFlowKey(key);
    final child = value.nodes.values.single;
    final CstNode pairValue;
    if (_isEmptyNode(child)) {
      pairValue = CstEmpty(start: position, value: child as YamlScalar);
    } else {
      _skipWhitespaceAndComments();
      pairValue = _buildNode(child);
    }
    return CstFlowPair(
      start: start,
      contentStart: contentStart,
      questionMark: questionMark,
      key: keyNode,
      colon: colon,
      pairValue: pairValue,
      value: value,
    );
  }

  /// Scans the `? key :` part of a flow mapping entry, in either its explicit
  /// or implicit form.
  ({int? questionMark, CstNode key, int? colon}) _buildFlowKey(YamlNode key) {
    final questionMark = _tryConsumeToken(YamlTokenKind.key);
    if (questionMark != null) {
      _skipWhitespaceAndComments();
    }

    final keyNode = _isEmptyNode(key)
        ? CstEmpty(start: position, value: key as YamlScalar)
        : _buildNode(key);

    final colon = _tryConsumeColon(keyEnd: keyNode.end);
    return (questionMark: questionMark, key: keyNode, colon: colon);
  }
}
