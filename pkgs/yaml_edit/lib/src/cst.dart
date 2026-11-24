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

import 'package:meta/meta.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

part 'cst_builder.dart';
part 'cst_tiling.dart';

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

  /// Whether this sequence's first entry shares its line with a preceding
  /// non-whitespace token (for example a compact sequence `- - 1` or `? - 1`).
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

  /// Start of the line the `-` is written on (past any leading BOM), or
  /// [start] when this is the first entry of a compact sequence sharing a line
  /// with an outer indicator.
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

  /// Whether this mapping's first entry shares its line with a preceding
  /// non-whitespace token (for example a compact mapping `- a: 1` or `? a: 1`).
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

  /// Start of the line the key is written on (past any leading BOM), or
  /// [start] when this is the first entry of a compact mapping sharing a line
  /// with an outer indicator.
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
