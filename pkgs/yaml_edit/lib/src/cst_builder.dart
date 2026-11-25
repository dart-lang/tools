// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cst.dart';

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
    final isBlock = (value is YamlMap && value.style != CollectionStyle.FLOW) ||
        (value is YamlList && value.style != CollectionStyle.FLOW);
    if (isBlock && !_hasOwnProperties(value)) {
      var lineStart = _lineTable.lineStartOf(position);
      if (lineStart < position && source.codeUnitAt(lineStart) == 0xFEFF) {
        lineStart++;
      }
      if (_isSpacesOrTabsRange(lineStart, position)) {
        position = lineStart;
      }
    }
    return _buildNode(value);
  }

  bool _hasOwnProperties(YamlNode node) {
    final firstKind = _tokensByOffset[node.span.start.offset]?.kind;
    if (firstKind != YamlTokenKind.anchor && firstKind != YamlTokenKind.tag) {
      return false;
    }
    if (node is YamlMap) {
      final firstKeyStart =
          (node.nodes.keys.firstOrNull as YamlNode?)?.span.start.offset;
      if (firstKeyStart == node.span.start.offset) return false;
    }
    return true;
  }

  bool _isSpacesOrTabsRange(int start, int end) {
    for (var i = start; i < end; i++) {
      final unit = source.codeUnitAt(i);
      if (unit != 0x20 && unit != 0x09) return false;
    }
    return true;
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
    final hasProperties = _hasOwnProperties(child);
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

  bool _hasNonTriviaBeforeOnLine(int offset) {
    final lineStart = _lineTable.lineStartOf(offset);
    for (var i = lineStart; i < offset; i++) {
      final unit = source.codeUnitAt(i);
      if (unit != 0x20 && unit != 0x09 && unit != 0xFEFF) return true;
    }
    return false;
  }

  CstBlockSeq _buildBlockSeq(int start, int contentStart, YamlList value) {
    final isCompact = _hasNonTriviaBeforeOnLine(contentStart);
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
    final isCompact = _hasNonTriviaBeforeOnLine(contentStart);
    final entries = <CstBlockMapEntry>[];
    value.nodes.forEach((key, child) {
      final entryStart = position;
      final lineStart = _skipCommentAndBlankLines();
      _skipSpaces();

      final questionMark = _tryConsumeToken(YamlTokenKind.key);
      final keyValue = key as YamlNode;
      final keyNode = questionMark != null
          ? _buildBlockChild(keyValue)
          : _isEmptyNode(keyValue)
              ? CstEmpty(start: position, value: keyValue as YamlScalar)
              : _buildNode(keyValue);

      final entryColumn = _lineTable.columnOf(questionMark ?? keyNode.start);
      final colon = _tryConsumeColon(
        keyEnd: keyNode.contentEnd,
        expectedColumnOnNewLine: entryColumn,
      );

      final valueNode = _buildBlockChild(child);

      final alreadyTerminatedLine = valueNode is CstBlockSeq ||
          valueNode is CstBlockMap ||
          (colon == null && (keyNode is CstBlockSeq || keyNode is CstBlockMap));

      entries.add(CstBlockMapEntry(
        start: entryStart,
        lineStart: lineStart,
        questionMark: questionMark,
        key: keyNode,
        colon: colon,
        value: valueNode,
        hasSeparatorComment:
            colon != null && _hasCommentBetween(colon + 1, valueNode.start),
        end: alreadyTerminatedLine ? valueNode.end : _consumeTrailingLine(),
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
