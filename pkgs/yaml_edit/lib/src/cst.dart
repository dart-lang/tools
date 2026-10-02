// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A concrete syntax tree (CST) for a single YAML document.
///
/// Built from the `YamlNode` value tree and `Token` stream produced by
/// `package:yaml` (`loadYamlDocument(..., retainTokens: true)`). Every node,
/// indicator, comment, and whitespace span is recorded with exact character
/// offsets (`[start, end)`).
///
/// A [CstDocument] forms a complete tiling of its source text: slots are
/// contiguous, non-overlapping, and ordered by source offset. Concatenating all
/// slots reproduces the original document byte for byte. [CstDocument.parse]
/// enforces this invariant on every document it constructs.
library;

import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

/// Thrown when the CST builder cannot produce an exact tiling of the source.
///
/// This indicates a document shape the builder does not model. It is a bug in
/// the builder rather than a problem with the document, and callers are
/// expected to treat it as unrecoverable.
final class CstException implements Exception {
  /// Explanation of why the CST tiling failed.
  final String message;

  /// The offset in the source at which the problem was detected.
  final int offset;

  CstException(this.message, this.offset);

  @override
  String toString() => 'CstException at $offset: $message';
}

/// A node of the concrete syntax tree.
///
/// Every node occupies the source range `[start, end)`. The range is split into
/// the *properties* `[start, contentStart)` — a verbatim anchor and/or tag,
/// including the whitespace separating it from the content — and the *content*
/// `[contentStart, end)`:
///
/// ```text
/// &anchor !tag scalar_or_collection
/// ^            ^                   ^
/// start        contentStart        contentEnd / end
/// ```
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

  /// The comment on the header line of a block scalar, if present.
  final CommentToken? headerComment;

  /// Offset where the whitespace preceding [headerComment] begins on the
  /// header line of a block scalar.
  final int? headerCommentPrefixStart;

  /// Offset just past the content on the header line of a block scalar, before
  /// any header comment whitespace or line break.
  final int? headerLineContentEnd;

  /// The style the scalar is written in.
  ScalarStyle get style => value.style;

  CstScalar({
    required this.start,
    required this.contentStart,
    required this.end,
    required this.value,
    this.headerComment,
    this.headerCommentPrefixStart,
    this.headerLineContentEnd,
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

  @override
  int get end => entries.last.end;

  @override
  int get contentEnd => entries.last.value.contentEnd;

  /// The column at which this sequence's `-` indicators are written.
  int get indent => entries.first.dashStart - entries.first.lineStart;

  CstBlockSeq({
    required this.start,
    required this.contentStart,
    required List<CstBlockSeqEntry> entries,
    required this.value,
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

  /// Start of the line the `-` is written on.
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

  /// A comment sitting between the `-` indicator and the entry value, if any.
  final CommentToken? separatorComment;

  /// Whether a comment sits between the `-` indicator and the entry value.
  bool get hasSeparatorComment => separatorComment != null;

  CstBlockSeqEntry({
    required this.start,
    required this.lineStart,
    required this.dashStart,
    required this.value,
    required this.end,
    this.separatorComment,
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

  @override
  int get end => entries.last.end;

  @override
  int get contentEnd => entries.last.value.contentEnd;

  /// The column at which this mapping's keys are written.
  int get indent => entries.first.keyStart - entries.first.lineStart;

  CstBlockMap({
    required this.start,
    required this.contentStart,
    required List<CstBlockMapEntry> entries,
    required this.value,
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

  /// Start of the line the key is written on. See [CstBlockSeqEntry.lineStart].
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

  /// A comment sitting between the `:` separator and the entry value, if any.
  final CommentToken? separatorComment;

  /// Whether a comment sits between the `:` separator and the entry value.
  bool get hasSeparatorComment => separatorComment != null;

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
    this.separatorComment,
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

  /// End of this entry: just past the `,` if there is one, otherwise the end of
  /// the whitespace and comments following the value.
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
    var hasCrlf = false;

    var index = 0;
    final length = source.length;
    while (index < length) {
      final char = source[index];
      if (char == '\r') {
        contentEnds.add(index);
        if (index + 1 < length && source[index + 1] == '\n') {
          hasCrlf = true;
          index += 2;
        } else {
          index += 1;
        }
        breakEnds.add(index);
        if (index < length) starts.add(index);
      } else if (char == '\n') {
        contentEnds.add(index);
        index += 1;
        breakEnds.add(index);
        if (index < length) starts.add(index);
      } else {
        index++;
      }
    }

    if (contentEnds.length < starts.length) {
      contentEnds.add(length);
      breakEnds.add(length);
    }

    return _LineTable._(
      lineStarts: List.unmodifiable(starts),
      lineContentEnds: List.unmodifiable(contentEnds),
      lineBreakEnds: List.unmodifiable(breakEnds),
      lineEnding: hasCrlf ? '\r\n' : '\n',
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

  /// All tokens retained during parsing, ordered by source offset.
  final List<Token> tokens;

  /// All comment tokens retained during parsing, ordered by source offset.
  final List<CommentToken> comments;

  /// The primary line terminator detected in this document.
  final String lineEnding;

  final _LineTable _lineTable;

  CstDocument._({
    required this.source,
    required this.root,
    required this.value,
    required List<Token> tokens,
    required List<CommentToken> comments,
    required this.lineEnding,
    required _LineTable lineTable,
  })  : tokens = List.unmodifiable(tokens),
        comments = List.unmodifiable(comments),
        _lineTable = lineTable;

  /// The set of nodes that are reachable more than once because of aliasing.
  ///
  /// A node appears here when it is the target of at least one alias. Editing
  /// such a node, or anything inside it, would silently change the document at
  /// every point that refers to it, so callers must refuse to do so.
  late final Set<YamlNode> aliasedValues = _collectAliasedValues(value);

  /// Returns the offset of the first character of the line containing [offset].
  int lineStartOf(int offset) => _lineTable.lineStartOf(offset);

  /// Returns the offset just before the line break terminating the line
  /// containing [offset], or `source.length` if the line has no line break.
  int lineContentEndOf(int offset) => _lineTable.lineContentEndOf(offset);

  /// Returns the offset just past the line break terminating the line
  /// containing [offset], or `source.length` if the line has no line break.
  int lineBreakEndOf(int offset) => _lineTable.lineBreakEndOf(offset);

  /// Returns the length of the line break starting at [offset] (2 for `\r\n`,
  /// 1 for `\n` or `\r`, 0 if none).
  int lineBreakLengthAt(int offset) {
    if (offset < 0 || offset >= source.length) return 0;
    final char = source[offset];
    if (char == '\r') {
      return (offset + 1 < source.length && source[offset + 1] == '\n') ? 2 : 1;
    }
    if (char == '\n') return 1;
    return 0;
  }

  /// Whether a line break starts at [offset].
  bool hasLineBreakAt(int offset) => lineBreakLengthAt(offset) > 0;

  /// Returns the length of the line break immediately preceding [offset].
  int lineBreakLengthBefore(int offset) {
    if (offset <= 0 || offset > source.length) return 0;
    final char = source[offset - 1];
    if (char == '\n') {
      return (offset - 1 > 0 && source[offset - 2] == '\r') ? 2 : 1;
    }
    if (char == '\r') return 1;
    return 0;
  }

  /// Whether a line break immediately precedes [offset].
  bool hasLineBreakBefore(int offset) => lineBreakLengthBefore(offset) > 0;

  /// Whether any line break occurs in `[start, end)`.
  bool hasLineBreakInRange(int start, int end) =>
      start < end && _lineTable.lineContentEndOf(start) < end;

  /// Zero-based column index of [offset] relative to the start of its line.
  int columnOf(int offset) => offset - lineStartOf(offset);

  /// Whether a space or tab immediately precedes [offset].
  bool hasWhitespaceBefore(int offset) {
    if (offset <= 0 || offset > source.length) return false;
    final char = source[offset - 1];
    return char == ' ' || char == '\t';
  }

  /// Returns the first [CommentToken] fully contained in `[start, end)`, or
  /// `null` if none exists.
  CommentToken? commentInRange(int start, int end) {
    for (final comment in comments) {
      final offset = comment.span.start.offset;
      if (offset >= end) break;
      if (offset >= start && comment.span.end.offset <= end) {
        return comment;
      }
    }
    return null;
  }

  /// Returns all [CommentToken]s fully contained in `[start, end)`.
  List<CommentToken> commentsInRange(int start, int end) {
    final result = <CommentToken>[];
    for (final comment in comments) {
      final offset = comment.span.start.offset;
      if (offset >= end) break;
      if (offset >= start && comment.span.end.offset <= end) {
        result.add(comment);
      }
    }
    return result;
  }

  /// Whether every character in `[start, end)` is a space or tab.
  bool isWhitespaceRange(int start, int end) {
    for (var i = start; i < end; i++) {
      final char = source[i];
      if (char != ' ' && char != '\t') return false;
    }
    return true;
  }

  /// Whether `[start, end)` contains a tab character (`\t`).
  bool hasTabInRange(int start, int end) {
    for (var i = start; i < end; i++) {
      if (source[i] == '\t') return true;
    }
    return false;
  }

  /// Extends [offset] past blank lines and full-line comments whose column is
  /// greater than [minIndent], returning the end of the last such line.
  int extendPastIndentedCommentsAndBlankLines(int offset, int minIndent) {
    var probe = offset;
    while (probe < source.length) {
      final lineStart = lineStartOf(probe);
      if (probe != lineStart) break;

      final lineContentEnd = lineContentEndOf(probe);
      final lineBreakEnd = lineBreakEndOf(probe);

      final comment = commentInRange(lineStart, lineContentEnd);
      if (comment != null) {
        final commentStart = comment.span.start.offset;
        final column = commentStart - lineStart;
        if (isWhitespaceRange(lineStart, commentStart) && column > minIndent) {
          probe = lineBreakEnd;
          continue;
        }
        break;
      }

      if (isWhitespaceRange(lineStart, lineContentEnd)) {
        probe = lineBreakEnd;
        continue;
      }

      break;
    }
    return probe;
  }

  /// Parses [source] into a CST.
  ///
  /// Throws a [YamlException] if [source] is not a valid YAML document, and a
  /// [CstException] if it is valid but the builder cannot tile it.
  factory CstDocument.parse(String source) {
    final yamlDocument = loadYamlDocument(source, retainTokens: true);
    final value = yamlDocument.contents;
    final allTokens = yamlDocument.tokens ?? const <Token>[];
    final lineTable = _LineTable(source);
    final builder = _CstBuilder(source, allTokens, lineTable);
    final root = builder.buildDocument(value);
    final comments = allTokens.whereType<CommentToken>().toList();
    final document = CstDocument._(
      source: source,
      root: root,
      value: value,
      tokens: allTokens,
      comments: comments,
      lineEnding: lineTable.lineEnding,
      lineTable: lineTable,
    );
    _checkTiling(document);
    return document;
  }
}

/// Collects the nodes reachable by more than one path, which is exactly the set
/// of nodes that some alias refers to.
Set<YamlNode> _collectAliasedValues(YamlNode root) {
  final aliased = <YamlNode>{};
  final visited = <YamlNode>{};
  void visit(YamlNode node) {
    if (!visited.add(node)) {
      aliased.add(node);
      return;
    }
    switch (node) {
      case YamlMap():
        node.nodes.forEach((key, value) {
          visit(key as YamlNode);
          visit(value);
        });
      case YamlList():
        node.nodes.forEach(visit);
      default:
    }
  }

  visit(root);
  return aliased;
}

// ---------------------------------------------------------------------------
// Tiling check
// ---------------------------------------------------------------------------

/// Verifies that [document]'s slots tile its source exactly.
///
/// Walks the tree in source order and checks that:
/// 1. Slot boundaries are monotonically non-decreasing (disjoint and ordered).
/// 2. Every structural indicator (`-`, `?`, `:`, `,`, `[`, `]`, `{`, `}`)
///    matches its expected character in the source.
/// 3. Every region between structural indicators and node contents contains
///    only whitespace and comments.
///
/// Throws a [CstException] if any check fails.
void _checkTiling(CstDocument document) {
  final source = document.source;
  var cursor = 0;

  /// Advances the cursor to [offset], requiring `[cursor, offset)` to hold only
  /// blank space and comments.
  void whitespaceAndComments(int offset, String what) {
    if (offset < cursor) {
      throw CstException(
          'slot "$what" starts at $offset, before the previous slot ended at '
          '$cursor',
          offset);
    }
    var index = cursor;
    while (index < offset) {
      final char = source[index];
      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        index++;
      } else if (char == '#') {
        while (
            index < offset && source[index] != '\n' && source[index] != '\r') {
          index++;
        }
      } else {
        throw CstException(
            'the source before "$what" was taken to be whitespace or comments, '
            'but holds ${_describe(source.substring(cursor, offset))}',
            index);
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
      throw CstException(
          'expected $what ("$char") at $offset but found $found', offset);
    }
    cursor = offset + 1;
  }

  /// Advances the cursor over a region whose contents are not whitespace or
  /// comments, such as a scalar's text or a node's anchor and tag.
  void opaque(int offset, String what) {
    if (offset < cursor) {
      throw CstException(
          'slot "$what" ends at $offset, before it started at $cursor', offset);
    }
    cursor = offset;
  }

  void visitNode(CstNode node) {
    whitespaceAndComments(node.start, 'node');
    opaque(node.contentStart, 'node properties');
    switch (node) {
      case CstScalar():
      case CstAlias():
      case CstEmpty():
        opaque(node.end, 'node content');
      case CstBlockSeq():
        for (final entry in node.entries) {
          whitespaceAndComments(entry.start, 'block sequence entry');
          whitespaceAndComments(entry.lineStart, 'block sequence entry line');
          indicator(entry.dashStart, '-', 'block sequence entry indicator');
          visitNode(entry.value);
          whitespaceAndComments(entry.end, 'end of block sequence entry');
        }
      case CstBlockMap():
        for (final entry in node.entries) {
          whitespaceAndComments(entry.start, 'block mapping entry');
          whitespaceAndComments(entry.lineStart, 'block mapping entry line');
          if (entry.questionMark case final questionMark?) {
            indicator(questionMark, '?', 'explicit key indicator');
          }
          visitNode(entry.key);
          if (entry.colon case final colon?) {
            indicator(colon, ':', 'key/value separator');
          }
          visitNode(entry.value);
          whitespaceAndComments(entry.end, 'end of block mapping entry');
        }
      case CstFlowPair():
        if (node.questionMark case final questionMark?) {
          indicator(questionMark, '?', 'explicit key indicator');
        }
        visitNode(node.key);
        if (node.colon case final colon?) {
          indicator(colon, ':', 'flow key/value separator');
        }
        visitNode(node.pairValue);
      case CstFlowCollection():
        indicator(node.contentStart, node is CstFlowSeq ? '[' : '{',
            'flow collection opening delimiter');
        for (final entry in node.entries) {
          whitespaceAndComments(entry.start, 'flow entry');
          if (entry.questionMark case final questionMark?) {
            indicator(questionMark, '?', 'explicit key indicator');
          }
          if (entry.key case final key?) {
            visitNode(key);
            if (entry.colon case final colon?) {
              indicator(colon, ':', 'flow key/value separator');
            }
          }
          visitNode(entry.value);
          if (entry.comma case final comma?) {
            indicator(comma, ',', 'flow entry separator');
          }
          whitespaceAndComments(entry.end, 'end of flow entry');
        }
        indicator(node.closeStart, node is CstFlowSeq ? ']' : '}',
            'flow collection closing delimiter');
    }
  }

  if (document.root case final root?) {
    // The prefix is exempt from the whitespace and comments check: it
    // legitimately holds directives and a `---` marker as well as comments. The
    // suffix likewise may hold `...`, and is simply whatever is left over.
    cursor = root.start;
    visitNode(root);
  }
  if (cursor > document.source.length) {
    throw CstException(
        'tiling runs past the end of the source '
        '($cursor > ${document.source.length})',
        cursor);
  }
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
/// tree and the token stream emitted by `package:yaml`.
///
/// The value tree tells the builder what to expect and in what order, while the
/// token stream provides exact spans for anchors, tags, aliases, scalars,
/// comments, and indicators.
final class _CstBuilder {
  final String source;
  final Map<int, Token> _tokensByOffset;
  final _LineTable _lineTable;
  int position = 0;

  _CstBuilder(this.source, List<Token> tokens, this._lineTable)
      : _tokensByOffset = {
          for (final token in tokens)
            if (token.span.length > 0) token.span.start.offset: token
        };

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
      } else if (_tokensByOffset[position] case CommentToken(:final span)) {
        position = span.end.offset;
      } else if (_isBreak(position)) {
        position = _pastBreak(position);
      } else {
        return;
      }
    }
  }

  /// Advances past whole lines that contain nothing but blank space and
  /// comments, and returns the offset at which the first line with content
  /// begins.
  ///
  /// Leaves [position] at that same offset, so the content line's own
  /// indentation is left unconsumed for the caller to attribute.
  int _skipCommentAndBlankLines() {
    while (true) {
      var probe = position;
      while (_isSpace(probe)) {
        probe++;
      }
      if (_tokensByOffset[probe] case CommentToken(:final span)) {
        probe = span.end.offset;
      }
      if (probe < length && _isBreak(probe)) {
        position = _pastBreak(probe);
        continue;
      }
      // Either content on this line, or trailing blank space at end of input.
      return position;
    }
  }

  /// Consumes the remainder of the current line if it holds nothing but blank
  /// space and an optional comment, and returns the resulting position.
  ///
  /// If the line has more content on it — as in a flow collection, or a nested
  /// block collection sharing a line with its parent — nothing is consumed.
  int _consumeTrailingLine() {
    var probe = position;
    while (_isSpace(probe)) {
      probe++;
    }
    if (_tokensByOffset[probe] case CommentToken(:final span)) {
      probe = span.end.offset;
    }
    if (probe >= length) {
      // Trailing blank space or a comment at end of input.
      position = probe;
    } else if (_isBreak(probe)) {
      position = _pastBreak(probe);
    }
    return position;
  }

  Never _fail(String message) => throw CstException(message, position);

  void _expectToken(TokenType expectedType, String what) {
    final token = _tokensByOffset[position];
    if (token == null || token.type != expectedType) {
      final found =
          token?.type ?? (atEnd ? '<end of input>' : '"${source[position]}"');
      _fail('expected $what ($expectedType) but found $found');
    }
    position = token.span.end.offset;
  }

  int? _tryConsumeToken(TokenType type) {
    final token = _tokensByOffset[position];
    if (token != null && token.type == type) {
      final start = position;
      position = token.span.end.offset;
      return start;
    }
    return null;
  }

  /// Whether [node] is written as nothing at all.
  ///
  /// `package:yaml` gives such nodes a zero-length span. No node that is
  /// actually written can have one: even `''` is two characters.
  static bool _isEmptyNode(YamlNode node) =>
      node is YamlScalar && node.span.length == 0;

  /// Builds the root node, leaving [position] just past it.
  CstNode? buildDocument(YamlNode value) {
    // A document with no node at all still parses as `null`, but the scalar
    // reported for it covers the document's comments and blank lines rather
    // than any content of its own. Detect that and treat the whole source as
    // prefix.
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

    // Aliases share their value — and therefore their span — with the node they
    // refer to. When we find an AliasToken emitted at `position`, use its exact
    // span.
    if (_tokensByOffset[position] case AliasToken(:final span)) {
      position = span.end.offset;
      return CstAlias(start: start, end: position, value: value);
    }

    if (_isEmptyNode(value)) {
      return CstEmpty(start: start, value: value as YamlScalar);
    }

    switch (value) {
      case YamlScalar():
        // A scalar may be written as nothing but an anchor and/or a tag, as in
        // `a: &anchor` or `- !!str`. It still denotes `null`, but it is not
        // zero-length, so it does not look empty. Bounding the scan by the
        // node's own end keeps it from running on into what follows.
        _skipProperties(limit: value.span.end.offset);
        return _buildScalar(start, position, value);

      case YamlList() when value.style == CollectionStyle.FLOW:
        _skipProperties(landsOn: TokenType.flowSequenceStart);
        return _buildFlowSeq(start, position, value);

      case YamlList():
        _skipProperties(crossesLineBreak: true);
        return _buildBlockSeq(start, position, value);

      case YamlMap() when value.style != CollectionStyle.FLOW:
        final firstKey = value.nodes.keys.firstOrNull as YamlNode?;
        final bound = firstKey != null && firstKey.span.start.offset >= position
            ? firstKey.span.start.offset
            : null;
        _skipProperties(
          crossesLineBreak: true,
          bound: bound,
        );
        return _buildBlockMap(start, position, value);

      case YamlMap():
        _skipProperties(landsOn: TokenType.flowMappingStart);
        if (_isBraced(value)) {
          return _buildFlowMap(start, position, value);
        }
        // A flow mapping written without braces is a single pair standing in
        // for a mapping inside a flow sequence, as in `[a: 1]`. It has no
        // delimiter of its own, so any anchor or tag written here belongs to
        // its key rather than to the pair.
        return _buildFlowPair(start, position, value);

      default:
        _fail('unsupported node type ${value.runtimeType}');
    }
  }

  /// Whether the flow mapping [value] is written with braces.
  ///
  /// A single pair may stand in for a mapping inside a flow sequence, and then
  /// there are no braces to find. A braced mapping starts at `{` and ends at
  /// `}`, whereas a bare flow pair starts at its key (or `?`) and ends at its
  /// value.
  bool _isBraced(YamlMap value) {
    final startToken = _tokensByOffset[position];
    final end = value.span.end.offset;
    final endToken = end > 0 ? _tokensByOffset[end - 1] : null;
    return startToken?.type == TokenType.flowMappingStart &&
        endToken?.type == TokenType.flowMappingEnd;
  }

  /// Consumes any anchor and tag tokens written before a node's content, along
  /// with the whitespace and comments separating them from it — but only if
  /// doing so lands where that node's content is required to begin.
  ///
  /// Uses the exact `AnchorToken` and `TagToken` spans emitted by
  /// `package:yaml`'s scanner.
  void _skipProperties({
    int? limit,
    int? bound,
    TokenType? landsOn,
    bool crossesLineBreak = false,
  }) {
    assert(
        [limit, landsOn, crossesLineBreak ? true : null].nonNulls.length == 1,
        'exactly one acceptance condition must be given');
    final maxOffset =
        limit ?? (bound != null && bound >= position ? bound : null) ?? length;
    final start = position;
    var sawBreak = false;

    while (position < maxOffset) {
      final token = _tokensByOffset[position];
      if (token is! AnchorToken && token is! TagToken) break;
      if (token!.span.end.offset > maxOffset) break;

      position = token.span.end.offset;
      while (position < maxOffset) {
        if (_isBreak(position)) {
          sawBreak = true;
          position = _pastBreak(position);
        } else if (_isSpace(position)) {
          position++;
        } else if (_tokensByOffset[position] case CommentToken(:final span)) {
          position = span.end.offset;
        } else {
          break;
        }
      }
    }

    if (position == start) return;
    final bool accepted;
    if (limit != null) {
      accepted = true;
    } else if (landsOn != null) {
      accepted = _tokensByOffset[position]?.type == landsOn;
    } else {
      accepted = sawBreak;
    }
    if (!accepted) position = start;
  }

  CstNode _buildScalar(int start, int contentStart, YamlScalar value) {
    var end = value.span.end.offset;
    CommentToken? headerComment;
    int? headerCommentPrefixStart;
    int? headerLineContentEnd;

    // Use token span for plain scalars to avoid character scanning.
    if (value.style == ScalarStyle.PLAIN) {
      if (_tokensByOffset[contentStart] case final ScalarToken token) {
        end = token.span.end.offset;
      }
    } else if (value.style == ScalarStyle.LITERAL ||
        value.style == ScalarStyle.FOLDED) {
      final headerLineBreak = _lineTable.lineBreakEndOf(contentStart);
      for (var offset = contentStart + 1; offset < headerLineBreak; offset++) {
        if (_tokensByOffset[offset] case final CommentToken comment) {
          headerComment = comment;
          var prefixStart = comment.span.start.offset;
          while (prefixStart > contentStart &&
              (source[prefixStart - 1] == ' ' ||
                  source[prefixStart - 1] == '\t')) {
            prefixStart--;
          }
          headerCommentPrefixStart = prefixStart;
          headerLineContentEnd = prefixStart;
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
      headerCommentPrefixStart: headerCommentPrefixStart,
      headerLineContentEnd: headerLineContentEnd,
    );
  }

  CstBlockSeq _buildBlockSeq(int start, int contentStart, YamlList value) {
    final entries = <CstBlockSeqEntry>[];
    for (final child in value.nodes) {
      final entryStart = position;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();
      final dashStart = position;
      _expectToken(TokenType.blockEntry, 'block sequence entry indicator');

      final CstNode childNode;
      if (_isEmptyNode(child)) {
        childNode = CstEmpty(start: position, value: child as YamlScalar);
      } else {
        final isBlock =
            (child is YamlMap && child.style != CollectionStyle.FLOW) ||
                (child is YamlList && child.style != CollectionStyle.FLOW);
        final firstChildToken = _tokensByOffset[child.span.start.offset];
        final hasProperties =
            firstChildToken is AnchorToken || firstChildToken is TagToken;
        if (isBlock &&
            !hasProperties &&
            _lineTable.lineStartOf(child.span.start.offset) >
                _lineTable.lineStartOf(position)) {
          _consumeTrailingLine();
        } else {
          _skipWhitespaceAndComments();
        }
        childNode = _buildNode(child);
      }

      CommentToken? separatorComment;
      for (var offset = dashStart + 1; offset < childNode.start; offset++) {
        if (_tokensByOffset[offset] case final CommentToken token) {
          separatorComment = token;
          break;
        }
      }

      entries.add(CstBlockSeqEntry(
        start: entryStart,
        lineStart: lineStart,
        dashStart: dashStart,
        value: childNode,
        separatorComment: separatorComment,
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
    );
  }

  CstBlockMap _buildBlockMap(int start, int contentStart, YamlMap value) {
    final entries = <CstBlockMapEntry>[];
    value.nodes.forEach((key, child) {
      final entryStart = position;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();

      final questionMark = _tryConsumeToken(TokenType.key);
      if (questionMark != null) {
        _skipWhitespaceAndComments();
      }

      final keyValue = key as YamlNode;
      final CstNode keyNode;
      if (_isEmptyNode(keyValue)) {
        keyNode = CstEmpty(start: position, value: keyValue as YamlScalar);
      } else {
        keyNode = _buildNode(keyValue);
      }

      // The `:` may be separated from the key by whitespace and comments, and
      // for an explicit key written without a value there may be no `:` at all.
      final beforeColon = position;
      _skipWhitespaceAndComments();
      final colon = _tryConsumeToken(TokenType.value);
      if (colon == null) {
        position = beforeColon;
      }

      final CstNode valueNode;
      if (_isEmptyNode(child)) {
        valueNode = CstEmpty(start: position, value: child as YamlScalar);
      } else {
        final isBlock =
            (child is YamlMap && child.style != CollectionStyle.FLOW) ||
                (child is YamlList && child.style != CollectionStyle.FLOW);
        final firstChildToken = _tokensByOffset[child.span.start.offset];
        final hasProperties =
            firstChildToken is AnchorToken || firstChildToken is TagToken;
        if (isBlock &&
            !hasProperties &&
            _lineTable.lineStartOf(child.span.start.offset) >
                _lineTable.lineStartOf(position)) {
          _consumeTrailingLine();
        } else {
          _skipWhitespaceAndComments();
        }
        valueNode = _buildNode(child);
      }

      CommentToken? separatorComment;
      if (colon != null) {
        for (var offset = colon + 1; offset < valueNode.start; offset++) {
          if (_tokensByOffset[offset] case final CommentToken token) {
            separatorComment = token;
            break;
          }
        }
      }

      entries.add(CstBlockMapEntry(
        start: entryStart,
        lineStart: lineStart,
        questionMark: questionMark,
        key: keyNode,
        colon: colon,
        value: valueNode,
        separatorComment: separatorComment,
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
    );
  }

  CstFlowSeq _buildFlowSeq(int start, int contentStart, YamlList value) {
    _expectToken(
        TokenType.flowSequenceStart, 'flow sequence opening delimiter');
    final entries = <CstFlowEntry>[];
    for (final child in value.nodes) {
      entries.add(_buildFlowEntry(key: null, child: child));
    }
    _skipWhitespaceAndComments();
    final closeStart = position;
    _expectToken(TokenType.flowSequenceEnd, 'flow sequence closing delimiter');
    final isMultiline = _lineTable.lineStartOf(closeStart) >
        _lineTable.lineStartOf(contentStart);
    return CstFlowSeq(
      start: start,
      contentStart: contentStart,
      entries: entries,
      closeStart: closeStart,
      isMultiline: isMultiline,
      value: value,
    );
  }

  CstFlowMap _buildFlowMap(int start, int contentStart, YamlMap value) {
    _expectToken(TokenType.flowMappingStart, 'flow mapping opening delimiter');
    final entries = <CstFlowEntry>[];
    value.nodes.forEach((key, child) {
      entries.add(_buildFlowEntry(key: key as YamlNode, child: child));
    });
    _skipWhitespaceAndComments();
    final closeStart = position;
    _expectToken(TokenType.flowMappingEnd, 'flow mapping closing delimiter');
    final isMultiline = _lineTable.lineStartOf(closeStart) >
        _lineTable.lineStartOf(contentStart);
    return CstFlowMap(
      start: start,
      contentStart: contentStart,
      entries: entries,
      closeStart: closeStart,
      isMultiline: isMultiline,
      value: value,
    );
  }

  CstFlowPair _buildFlowPair(int start, int contentStart, YamlMap value) {
    if (value.nodes.length != 1) {
      _fail('a flow mapping written without braces must hold exactly one pair, '
          'but this one holds ${value.nodes.length}');
    }
    final key = value.nodes.keys.single as YamlNode;
    final (:questionMark, key: keyNode, :colon) = _buildFlowKey(key);
    final child = value.nodes.values.single;
    return CstFlowPair(
      start: start,
      contentStart: contentStart,
      questionMark: questionMark,
      key: keyNode,
      colon: colon,
      pairValue: _buildFlowValue(child),
      value: value,
    );
  }

  CstFlowEntry _buildFlowEntry({
    required YamlNode? key,
    required YamlNode child,
  }) {
    final entryStart = position;
    _skipWhitespaceAndComments();

    int? questionMark;
    CstNode? keyNode;
    int? colon;
    if (key != null) {
      (:questionMark, key: keyNode, :colon) = _buildFlowKey(key);
    }

    final valueNode = _buildFlowValue(child);

    final afterValue = position;
    _skipWhitespaceAndComments();
    final comma = _tryConsumeToken(TokenType.flowEntry);
    if (comma == null) {
      position = afterValue;
    }

    return CstFlowEntry(
      start: entryStart,
      questionMark: questionMark,
      key: keyNode,
      colon: colon,
      value: valueNode,
      comma: comma,
      end: position,
    );
  }

  /// Scans the `? key :` part of a flow mapping entry, in either its explicit
  /// or implicit form.
  ({int? questionMark, CstNode key, int? colon}) _buildFlowKey(YamlNode key) {
    final questionMark = _tryConsumeToken(TokenType.key);
    if (questionMark != null) {
      _skipWhitespaceAndComments();
    }

    final keyNode = _isEmptyNode(key)
        ? CstEmpty(start: position, value: key as YamlScalar)
        : _buildNode(key);

    // An explicit key may be written without a value, in which case there is
    // no `:` to find.
    final beforeColon = position;
    _skipWhitespaceAndComments();
    final colon = _tryConsumeToken(TokenType.value);
    if (colon == null) {
      position = beforeColon;
    }
    return (questionMark: questionMark, key: keyNode, colon: colon);
  }

  /// Scans the value of a flow mapping entry or sequence entry.
  CstNode _buildFlowValue(YamlNode child) {
    if (_isEmptyNode(child)) {
      return CstEmpty(start: position, value: child as YamlScalar);
    }
    _skipWhitespaceAndComments();
    return _buildNode(child);
  }
}
