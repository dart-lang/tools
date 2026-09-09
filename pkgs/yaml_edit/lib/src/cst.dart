// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'char_codes.dart';
import 'editor.dart';

/// A representation of non-semantic source elements (comments, whitespace,
/// newlines).
sealed class CstTrivia {
  String get text;
  int get length => text.length;
}

class CstWhitespace extends CstTrivia {
  @override
  final String text;
  CstWhitespace(this.text);
  @override
  String toString() => 'Ws($length)';
}

class CstComment extends CstTrivia {
  @override
  final String text;
  CstComment(this.text);
  @override
  String toString() => 'Comment("$text")';
}

class CstNewline extends CstTrivia {
  @override
  final String text;
  CstNewline(this.text);
  @override
  String toString() => 'Newline';
}

/// A structured entry in a YAML map Concrete Syntax Tree.
///
/// Enforces that an entry's leading trivia (including multi-line documentation
/// comments) belongs to the entry as an indivisible unit, preventing insertions
/// from splitting comment headers.
class CstMapEntry {
  /// The offset where the entry's leading trivia starts (or key starts if no
  /// trivia).
  final int leadingTriviaOffset;

  /// The leading trivia text preceding this entry.
  final String leadingTriviaText;

  /// The AST node of the key.
  final YamlNode keyNode;

  /// The true source span of the key.
  final SourceSpan keySpan;

  /// The offset of the association colon `:`, or `-1` if no colon is present
  /// (e.g. an explicit key without a colon).
  final int colonOffset;

  /// The AST node of the value.
  final YamlNode valueNode;

  /// The true source span of the value.
  final SourceSpan valueSpan;

  /// The content-sensitive ending offset of the value.
  final int valueContentEnd;

  /// Trailing same-line comment or whitespace following the value.
  final String trailingTriviaText;

  CstMapEntry({
    required this.leadingTriviaOffset,
    required this.leadingTriviaText,
    required this.keyNode,
    required this.keySpan,
    required this.colonOffset,
    required this.valueNode,
    required this.valueSpan,
    required this.valueContentEnd,
    required this.trailingTriviaText,
  });
}

/// A Concrete Syntax Tree representing a YAML map collection.
class CstMap {
  final YamlMap map;
  final YamlEditor editor;
  final List<CstMapEntry> entries;

  /// Offset where a map header (e.g. `&anchor` or `!tag`) begins, if any.
  final int headerStartOffset;

  /// Offset where map content begins.
  final int contentStartOffset;

  /// Offset where map content ends.
  final int contentEndOffset;

  CstMap({
    required this.map,
    required this.editor,
    required this.entries,
    required this.headerStartOffset,
    required this.contentStartOffset,
    required this.contentEndOffset,
  });

  /// Parses [map] into a [CstMap] using [editor] for true span resolution.
  factory CstMap.parse(YamlEditor editor, YamlMap map) {
    final yaml = editor.toString();
    final entries = <CstMapEntry>[];

    final mapStart = map.span.start.offset;
    final mapEnd = map.span.end.offset;

    // Detect if map has a header tag/anchor preceding the first key
    var firstKeyStart = mapEnd;
    if (map.nodes.isNotEmpty) {
      final firstKey = map.nodes.keys.first as YamlNode;
      firstKeyStart = firstKey.span.start.offset;
    }

    var headerStart = mapStart;
    var prevLineEnd = (firstKeyStart < mapStart) ? mapStart : firstKeyStart;

    // Check for comment/indent lines before first key
    if (map.nodes.isNotEmpty) {
      final firstKey = map.nodes.keys.first as YamlNode;
      final kStart = firstKey.span.start.offset;
      var scan = kStart;
      while (scan > mapStart) {
        final prevNl = yaml.lastIndexOf('\n', scan - 1);
        if (prevNl < mapStart - 1) {
          final line = yaml.substring(mapStart, scan).trim();
          if (line.startsWith('#') || line.isEmpty) {
            scan = mapStart;
          }
          break;
        }
        final line = yaml.substring(prevNl + 1, scan).trim();
        if (line.startsWith('#') || line.isEmpty) {
          scan = prevNl + 1;
        } else {
          break;
        }
      }
      prevLineEnd = scan;
    }

    for (var i = 0; i < map.nodes.length; i++) {
      final keyNode = map.nodes.keys.elementAt(i) as YamlNode;
      final valueNode = map.nodes.values.elementAt(i);

      final keySpan = keyNode.span;
      final kStart = keySpan.start.offset;
      final kEnd = keySpan.end.offset;

      final colonOffset = _findColon(yaml, kEnd);

      final trueValueSpan = editor.getTrueSpan(map, keyNode, valueNode);
      final valueContentEnd =
          editor.getTrueContentSensitiveEnd(map, keyNode, valueNode);

      var triviaStart = prevLineEnd;
      if (triviaStart > kStart) triviaStart = kStart;

      final leadingTrivia = yaml.substring(triviaStart, kStart);

      var nextNl = yaml.indexOf('\n', valueContentEnd);
      var trailingTrivia = '';
      if (nextNl != -1) {
        trailingTrivia = yaml.substring(valueContentEnd, nextNl + 1);
        prevLineEnd = nextNl + 1;
      } else {
        trailingTrivia = yaml.substring(valueContentEnd);
        prevLineEnd = yaml.length;
      }

      entries.add(CstMapEntry(
        leadingTriviaOffset: triviaStart,
        leadingTriviaText: leadingTrivia,
        keyNode: keyNode,
        keySpan: keySpan,
        colonOffset: colonOffset,
        valueNode: valueNode,
        valueSpan: trueValueSpan,
        valueContentEnd: valueContentEnd,
        trailingTriviaText: trailingTrivia,
      ));
    }

    return CstMap(
      map: map,
      editor: editor,
      entries: entries,
      headerStartOffset: headerStart,
      contentStartOffset: mapStart,
      contentEndOffset: mapEnd,
    );
  }

  static int _findColon(String yaml, int startOffset) {
    var i = startOffset;
    while (i < yaml.length) {
      final c = yaml.codeUnitAt(i);
      if (YamlChar.isWhitespace(c) || YamlChar.isLineBreak(c)) {
        i++;
      } else if (c == YamlChar.hash) {
        i++;
        while (i < yaml.length && !YamlChar.isLineBreak(yaml.codeUnitAt(i))) {
          i++;
        }
      } else if (c == YamlChar.colon) {
        return i;
      } else {
        return -1;
      }
    }
    return -1;
  }
}

/// A structured entry in a YAML list Concrete Syntax Tree.
class CstListEntry {
  final int leadingTriviaOffset;
  final String leadingTriviaText;
  final int hyphenOffset;
  final YamlNode valueNode;
  final SourceSpan valueSpan;
  final int valueContentEnd;
  final String trailingTriviaText;

  CstListEntry({
    required this.leadingTriviaOffset,
    required this.leadingTriviaText,
    required this.hyphenOffset,
    required this.valueNode,
    required this.valueSpan,
    required this.valueContentEnd,
    required this.trailingTriviaText,
  });
}

/// A Concrete Syntax Tree representing a YAML list collection.
class CstList {
  final YamlList list;
  final YamlEditor editor;
  final List<CstListEntry> entries;

  CstList({
    required this.list,
    required this.editor,
    required this.entries,
  });

  factory CstList.parse(YamlEditor editor, YamlList list) {
    final yaml = editor.toString();
    final entries = <CstListEntry>[];
    var prevLineEnd = list.span.start.offset;

    for (var i = 0; i < list.nodes.length; i++) {
      final valueNode = list.nodes[i];
      final trueSpan = editor.getTrueSpan(list, i, valueNode);
      final valueContentEnd =
          editor.getTrueContentSensitiveEnd(list, i, valueNode);

      var hyphenOffset = -1;
      if (list.style == CollectionStyle.BLOCK) {
        hyphenOffset = yaml.lastIndexOf('-', trueSpan.start.offset);
      }

      var triviaStart = prevLineEnd;
      if (hyphenOffset != -1 && triviaStart > hyphenOffset) {
        triviaStart = hyphenOffset;
      } else if (hyphenOffset == -1 && triviaStart > trueSpan.start.offset) {
        triviaStart = trueSpan.start.offset;
      }

      final leadingTrivia = yaml.substring(triviaStart,
          hyphenOffset != -1 ? hyphenOffset : trueSpan.start.offset);

      var nextNl = yaml.indexOf('\n', valueContentEnd);
      var trailingTrivia = '';
      if (nextNl != -1) {
        trailingTrivia = yaml.substring(valueContentEnd, nextNl + 1);
        prevLineEnd = nextNl + 1;
      } else {
        trailingTrivia = yaml.substring(valueContentEnd);
        prevLineEnd = yaml.length;
      }

      entries.add(CstListEntry(
        leadingTriviaOffset: triviaStart,
        leadingTriviaText: leadingTrivia,
        hyphenOffset: hyphenOffset,
        valueNode: valueNode,
        valueSpan: trueSpan,
        valueContentEnd: valueContentEnd,
        trailingTriviaText: trailingTrivia,
      ));
    }

    return CstList(list: list, editor: editor, entries: entries);
  }
}
