// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A concrete syntax tree (CST) for a single YAML document.
///
/// # Why
///
/// `package:yaml` produces a *value* tree: it tells us what a document means,
/// but not how it is written. Comments, blank lines, indentation, delimiter
/// positions and collection styles are all absent. Editing a document while
/// preserving its layout therefore requires recovering that information, and
/// recovering it by scanning the source with ad-hoc heuristics is what makes
/// layout-preserving editors fragile.
///
/// The CST recovers it once, structurally, and records the result as offsets.
///
/// # The tiling invariant
///
/// The central invariant is that a [CstDocument] is a **tiling** of its source:
/// every character belongs to exactly one slot, slots are contiguous, and the
/// slots appear in source order. Concatenating all slots reproduces the source
/// byte for byte.
///
/// This is checked by [CstDocument.parse] on every document it builds, so it is
/// an enforced invariant rather than an aspiration. Two consequences follow:
///
/// * *Losslessness is structural.* There is no separate "printer" that might
///   disagree with the parser, so there is no round-trip property left to get
///   wrong.
/// * *Edits have an exact frame.* Any edit expressed as "replace the source
///   range of slot X" is guaranteed to leave every other character of the
///   document untouched, because the slots are disjoint.
///
/// Together these mean the editing code never has to search the source for a
/// delimiter: every offset it needs is already a slot boundary.
library;

import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

/// Thrown when the CST builder cannot produce an exact tiling of the source.
///
/// This indicates a document shape the builder does not model. It is a bug in
/// the builder rather than a problem with the document, and callers are
/// expected to treat it as unrecoverable.
final class CstException implements Exception {
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
/// `[contentStart, end)`.
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

  /// The style the scalar is written in.
  ScalarStyle get style => value.style;

  CstScalar({
    required this.start,
    required this.contentStart,
    required this.end,
    required this.value,
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
  ///
  /// Taken from the first entry; YAML requires the rest to agree.
  int get indent => entries.first.dashStart - entries.first.lineStart;

  CstBlockSeq({
    required this.start,
    required this.contentStart,
    required this.entries,
    required this.value,
  });
}

/// One `- value` entry of a [CstBlockSeq].
///
/// The entry tiles as `[start, lineStart)` leading comment and blank lines,
/// `[lineStart, dashStart)` the indentation of the `-`, the `-` itself,
/// `[dashStart + 1, value.start)` separating whitespace and comments, the
/// value, and `[value.end, end)` the trailing part of the value's line.
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

  final CstNode value;

  /// End of this entry, just past the line break that terminates it.
  ///
  /// The range `[value.end, end)` holds the remainder of the value's line:
  /// trailing spaces, an optional trailing comment, and the line break. That
  /// trailing comment belongs to this entry and is removed with it.
  final int end;

  CstBlockSeqEntry({
    required this.start,
    required this.lineStart,
    required this.dashStart,
    required this.value,
    required this.end,
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
    required this.entries,
    required this.value,
  });
}

/// One `key: value` entry of a [CstBlockMap].
final class CstBlockMapEntry {
  /// Start of this entry's leading comment and blank lines, immediately after
  /// the previous entry.
  final int start;

  /// Start of the line the key is written on. See [CstBlockSeqEntry.lineStart].
  final int lineStart;

  /// Offset of the `?` indicator, for entries written in explicit key form.
  final int? questionMark;

  final CstNode key;

  /// Offset of the `:` separating key from value.
  ///
  /// `null` for an explicit-key entry written without a value, as in `? a`.
  final int? colon;

  final CstNode value;

  /// End of this entry, just past the line break that terminates it.
  final int end;

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
  });
}

/// A collection written in flow style, as `[...]` or `{...}`.
sealed class CstFlowCollection extends CstNode {
  @override
  final int start;
  @override
  final int contentStart;

  /// The entries of this collection, in source order. May be empty.
  final List<CstFlowEntry> entries;

  /// Offset of the closing `]` or `}`.
  final int closeStart;

  CstFlowCollection({
    required this.start,
    required this.contentStart,
    required this.entries,
    required this.closeStart,
  });

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
    required this.value,
  });
}

/// One entry of a [CstFlowCollection].
///
/// The entry tiles as leading whitespace and comments, an optional `?`, the key
/// and `:` if this is a mapping entry, the value, then trailing whitespace and
/// comments and an optional `,`.
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

  final CstNode key;

  /// Offset of the `:` separating key from value, if present.
  final int? colon;

  /// The value of the pair.
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

  CstDocument._({
    required this.source,
    required this.root,
    required this.value,
  });

  /// The set of nodes that are reachable more than once because of aliasing.
  ///
  /// A node appears here when it is the target of at least one alias. Editing
  /// such a node, or anything inside it, would silently change the document at
  /// every point that refers to it, so callers must refuse to do so.
  late final Set<YamlNode> aliasedValues = _collectAliasedValues(value);

  int lineStartOf(int offset) {
    var lineStart = offset;
    while (lineStart > 0 &&
        source[lineStart - 1] != '\n' &&
        source[lineStart - 1] != '\r') {
      lineStart--;
    }
    return lineStart;
  }

  /// The column [offset] sits at, counting from zero.
  ///
  /// New content has to be indented to line up with the content around it, and
  /// that means knowing what column something is written at. Scanning back to
  /// the start of the line answers that exactly, and unlike searching for a
  /// delimiter it cannot be wrong: where a line begins is not a question about
  /// YAML.
  int columnOf(int offset) => offset - lineStartOf(offset);

  /// Parses [source] into a CST.
  ///
  /// Throws a [YamlException] if [source] is not a valid YAML document, and a
  /// [CstException] if it is valid but the builder cannot tile it.
  factory CstDocument.parse(String source) {
    final yamlDoc = loadYamlDocument(source, retainTokens: true);
    final value = yamlDoc.contents;
    final builder = _CstBuilder(source, yamlDoc.tokens ?? const []);
    final root = builder.buildDocument(value);
    final document = CstDocument._(
      source: source,
      root: root,
      value: value,
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
/// Walks the tree in source order and checks three things:
///
/// 1. Boundaries never run backwards, so the slots are disjoint and ordered.
/// 2. Every named indicator really is the character the model claims — the `-`
///    of a sequence entry really is a `-`, and so on.
/// 3. Every region the model treats as whitespace or comments contains nothing
///    but blank space and comments.
///
/// The third check is the one that matters. Losslessness alone is easy to
/// satisfy — taking substrings between boundaries reproduces the source no
/// matter where the boundaries are — so it would not catch a boundary in the
/// wrong place. Requiring that the spaces between the structure really are
/// empty of content is what rules out misattribution, and misattribution is
/// what makes an edit delete the wrong text.
///
/// This runs on every document rather than behind an assertion: it is the
/// invariant the rest of the design relies on, and a document the builder
/// cannot model must be rejected rather than silently mangled.
///
/// Throws a [CstException] if any of the three fails.
void _checkTiling(CstDocument document) {
  final src = document.source;
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
      final char = src[index];
      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        index++;
      } else if (char == '#') {
        while (index < offset && src[index] != '\n' && src[index] != '\r') {
          index++;
        }
      } else {
        throw CstException(
            'the source before "$what" was taken to be whitespace or comments, '
            'but holds ${_describe(src.substring(cursor, offset))}',
            index);
      }
    }
    cursor = offset;
  }

  /// Advances the cursor past an indicator that must be [char].
  void indicator(int offset, String char, String what) {
    whitespaceAndComments(offset, what);
    if (offset >= src.length || src[offset] != char) {
      throw CstException(
          'expected $what ("$char") at $offset but found '
          '${offset >= src.length ? "<end of input>" : _describe(src[offset])}',
          offset);
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
  final String src;
  final Map<int, Token> _tokensByOffset;
  int pos = 0;

  _CstBuilder(this.src, List<Token> tokens)
      : _tokensByOffset = {
          for (final token in tokens)
            if (token.span.length > 0) token.span.start.offset: token
        };

  int get length => src.length;

  bool get atEnd => pos >= length;

  bool _isSpace(int offset) =>
      offset < length && (src[offset] == ' ' || src[offset] == '\t');

  bool _isBreak(int offset) =>
      offset < length && (src[offset] == '\n' || src[offset] == '\r');

  /// Returns the offset just past the line break starting at [offset].
  int _pastBreak(int offset) {
    if (src[offset] == '\r' && offset + 1 < length && src[offset + 1] == '\n') {
      return offset + 2;
    }
    return offset + 1;
  }

  /// Advances past spaces and tabs.
  void _skipSpaces() {
    while (_isSpace(pos)) {
      pos++;
    }
  }

  /// Advances past spaces, tabs, line breaks, and comments.
  void _skipWhitespaceAndComments() {
    while (!atEnd) {
      if (_isSpace(pos)) {
        pos++;
      } else if (_tokensByOffset[pos] case CommentToken(:final span)) {
        pos = span.end.offset;
      } else if (_isBreak(pos)) {
        pos = _pastBreak(pos);
      } else {
        return;
      }
    }
  }

  /// Advances past whole lines that contain nothing but blank space and
  /// comments, and returns the offset at which the first line with content
  /// begins.
  ///
  /// Leaves [pos] at that same offset, so the content line's own indentation is
  /// left unconsumed for the caller to attribute.
  int _skipCommentAndBlankLines() {
    while (true) {
      var probe = pos;
      while (_isSpace(probe)) {
        probe++;
      }
      if (_tokensByOffset[probe] case CommentToken(:final span)) {
        probe = span.end.offset;
      }
      if (probe < length && _isBreak(probe)) {
        pos = _pastBreak(probe);
        continue;
      }
      // Either content on this line, or trailing blank space at end of input.
      return pos;
    }
  }

  /// Consumes the remainder of the current line if it holds nothing but blank
  /// space and an optional comment, and returns the resulting position.
  ///
  /// If the line has more content on it — as in a flow collection, or a nested
  /// block collection sharing a line with its parent — nothing is consumed.
  int _consumeTrailingLine() {
    var probe = pos;
    while (_isSpace(probe)) {
      probe++;
    }
    if (_tokensByOffset[probe] case CommentToken(:final span)) {
      probe = span.end.offset;
    }
    if (probe >= length) {
      // Trailing blank space or a comment at end of input.
      pos = probe;
    } else if (_isBreak(probe)) {
      pos = _pastBreak(probe);
    }
    return pos;
  }

  Never _fail(String message) => throw CstException(message, pos);

  void _expectToken(TokenType expectedType, String what) {
    final token = _tokensByOffset[pos];
    if (token == null || token.type != expectedType) {
      _fail('expected $what ($expectedType) but found '
          '${token?.type ?? (atEnd ? "<end of input>" : '"${src[pos]}"')}');
    }
    pos = token.span.end.offset;
  }

  int? _tryConsumeToken(TokenType type) {
    final token = _tokensByOffset[pos];
    if (token != null && token.type == type) {
      final start = pos;
      pos = token.span.end.offset;
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

  /// Builds the root node, leaving [pos] just past it.
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
    pos = value.span.start.offset;
    return _buildNode(value);
  }

  /// Builds the node [value], which must start at [pos].
  CstNode _buildNode(YamlNode value) {
    final start = pos;

    // Aliases share their value — and therefore their span — with the node they
    // refer to. When we find an AliasToken emitted at `pos`, use its exact
    // span.
    if (_tokensByOffset[pos] case AliasToken(:final span)) {
      pos = span.end.offset;
      return CstAlias(start: start, end: pos, value: value);
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
        return _buildScalar(start, pos, value);

      case YamlList() when value.style == CollectionStyle.FLOW:
        _skipProperties(landsOn: TokenType.flowSequenceStart);
        return _buildFlowSeq(start, pos, value);

      case YamlList():
        _skipProperties(crossesLineBreak: true);
        return _buildBlockSeq(start, pos, value);

      case YamlMap() when value.style != CollectionStyle.FLOW:
        final firstKey = value.nodes.keys.firstOrNull as YamlNode?;
        _skipProperties(
          crossesLineBreak: true,
          bound: firstKey?.span.start.offset,
        );
        return _buildBlockMap(start, pos, value);

      case YamlMap() when _isBraced(value):
        _skipProperties(landsOn: TokenType.flowMappingStart);
        return _buildFlowMap(start, pos, value);

      case YamlMap():
        // A flow mapping written without braces is a single pair standing in
        // for a mapping inside a flow sequence, as in `[a: 1]`. It has no
        // delimiter of its own, so any anchor or tag written here belongs to
        // its key rather than to the pair.
        return _buildFlowPair(start, pos, value);

      default:
        _fail('unsupported node type ${value.runtimeType}');
    }
  }

  /// Whether the flow mapping [value] is written with braces.
  ///
  /// A single pair may stand in for a mapping inside a flow sequence, and then
  /// there are no braces to find. Looking at the opening character is not
  /// enough, because the pair's key may itself be a braced flow mapping, as in
  /// `[{a: 1}: b]`. The last token settles it: a braced mapping ends in `}`
  /// ([TokenType.flowMappingEnd]) and a bare pair ends in its value.
  bool _isBraced(YamlMap value) {
    final end = value.span.end.offset;
    return end > 0 &&
        _tokensByOffset[end - 1]?.type == TokenType.flowMappingEnd;
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
    final maxOffset = limit ?? bound ?? length;
    final start = pos;
    var sawBreak = false;

    while (pos < maxOffset) {
      final token = _tokensByOffset[pos];
      if (token is! AnchorToken && token is! TagToken) break;
      if (token!.span.end.offset > maxOffset) break;

      pos = token.span.end.offset;
      while (pos < maxOffset) {
        if (_isBreak(pos)) {
          sawBreak = true;
          pos = _pastBreak(pos);
        } else if (_isSpace(pos)) {
          pos++;
        } else if (_tokensByOffset[pos] case CommentToken(:final span)) {
          pos = span.end.offset;
        } else {
          break;
        }
      }
    }

    if (pos == start) return;
    final accepted = switch (null) {
      _ when limit != null => true,
      _ when landsOn != null => _tokensByOffset[pos]?.type == landsOn,
      _ => sawBreak,
    };
    if (!accepted) pos = start;
  }

  CstNode _buildScalar(int start, int contentStart, YamlScalar value) {
    var end = value.span.end.offset;
    // A plain scalar's span can extend past the scalar itself: at the root of a
    // document it includes the trailing line break. Plain scalars cannot end in
    // white space, so trimming it back is always safe and never loses content.
    if (value.style == ScalarStyle.PLAIN) {
      while (end > contentStart &&
          (src[end - 1] == ' ' ||
              src[end - 1] == '\t' ||
              src[end - 1] == '\n' ||
              src[end - 1] == '\r')) {
        end--;
      }
    }
    if (end < contentStart) {
      _fail('scalar ends before it starts');
    }
    pos = end;
    return CstScalar(
      start: start,
      contentStart: contentStart,
      end: end,
      value: value,
    );
  }

  CstBlockSeq _buildBlockSeq(int start, int contentStart, YamlList value) {
    final entries = <CstBlockSeqEntry>[];
    for (final child in value.nodes) {
      final entryStart = pos;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();
      final dashStart = pos;
      _expectToken(TokenType.blockEntry, 'block sequence entry indicator');

      final CstNode childNode;
      if (_isEmptyNode(child)) {
        childNode = CstEmpty(start: pos, value: child as YamlScalar);
      } else {
        final isBlock =
            (child is YamlMap && child.style != CollectionStyle.FLOW) ||
                (child is YamlList && child.style != CollectionStyle.FLOW);
        final firstChildToken = _tokensByOffset[child.span.start.offset];
        final hasProperties =
            firstChildToken is AnchorToken || firstChildToken is TagToken;
        if (isBlock &&
            !hasProperties &&
            src.substring(pos, child.span.start.offset).contains('\n')) {
          _consumeTrailingLine();
        } else {
          _skipWhitespaceAndComments();
        }
        childNode = _buildNode(child);
      }

      entries.add(CstBlockSeqEntry(
        start: entryStart,
        lineStart: lineStart,
        dashStart: dashStart,
        value: childNode,
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
      final entryStart = pos;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();

      final questionMark = _tryConsumeToken(TokenType.key);
      if (questionMark != null) {
        _skipWhitespaceAndComments();
      }

      final keyValue = key as YamlNode;
      final CstNode keyNode;
      if (_isEmptyNode(keyValue)) {
        keyNode = CstEmpty(start: pos, value: keyValue as YamlScalar);
      } else {
        keyNode = _buildNode(keyValue);
      }

      // The `:` may be separated from the key by whitespace and comments, and
      // for an explicit key written without a value there may be no `:` at all.
      final beforeColon = pos;
      _skipWhitespaceAndComments();
      final colon = _tryConsumeToken(TokenType.value);
      if (colon == null) {
        pos = beforeColon;
      }

      final CstNode valueNode;
      if (_isEmptyNode(child)) {
        valueNode = CstEmpty(start: pos, value: child as YamlScalar);
      } else {
        final isBlock =
            (child is YamlMap && child.style != CollectionStyle.FLOW) ||
                (child is YamlList && child.style != CollectionStyle.FLOW);
        final firstChildToken = _tokensByOffset[child.span.start.offset];
        final hasProperties =
            firstChildToken is AnchorToken || firstChildToken is TagToken;
        if (isBlock &&
            !hasProperties &&
            src.substring(pos, child.span.start.offset).contains('\n')) {
          _consumeTrailingLine();
        } else {
          _skipWhitespaceAndComments();
        }
        valueNode = _buildNode(child);
      }

      entries.add(CstBlockMapEntry(
        start: entryStart,
        lineStart: lineStart,
        questionMark: questionMark,
        key: keyNode,
        colon: colon,
        value: valueNode,
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
    final closeStart = pos;
    _expectToken(TokenType.flowSequenceEnd, 'flow sequence closing delimiter');
    return CstFlowSeq(
      start: start,
      contentStart: contentStart,
      entries: entries,
      closeStart: closeStart,
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
    final closeStart = pos;
    _expectToken(TokenType.flowMappingEnd, 'flow mapping closing delimiter');
    return CstFlowMap(
      start: start,
      contentStart: contentStart,
      entries: entries,
      closeStart: closeStart,
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
    final entryStart = pos;
    _skipWhitespaceAndComments();

    int? questionMark;
    CstNode? keyNode;
    int? colon;
    if (key != null) {
      (:questionMark, key: keyNode, :colon) = _buildFlowKey(key);
    }

    final valueNode = _buildFlowValue(child);

    final afterValue = pos;
    _skipWhitespaceAndComments();
    final comma = _tryConsumeToken(TokenType.flowEntry);
    if (comma == null) {
      pos = afterValue;
    }

    return CstFlowEntry(
      start: entryStart,
      questionMark: questionMark,
      key: keyNode,
      colon: colon,
      value: valueNode,
      comma: comma,
      end: pos,
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
        ? CstEmpty(start: pos, value: key as YamlScalar)
        : _buildNode(key);

    // An explicit key may be written without a value, in which case there is
    // no `:` to find.
    final beforeColon = pos;
    _skipWhitespaceAndComments();
    final colon = _tryConsumeToken(TokenType.value);
    if (colon == null) {
      pos = beforeColon;
    }
    return (questionMark: questionMark, key: keyNode, colon: colon);
  }

  /// Scans the value of a flow mapping entry or sequence entry.
  CstNode _buildFlowValue(YamlNode child) {
    if (_isEmptyNode(child)) {
      return CstEmpty(start: pos, value: child as YamlScalar);
    }
    _skipWhitespaceAndComments();
    return _buildNode(child);
  }
}
