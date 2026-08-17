// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import 'block_syntax.dart';

/// Parses atx-style headers: `## Header ##`.
class HeaderSyntax extends BlockSyntax {
  @override
  RegExp get pattern => headerPattern;

  const HeaderSyntax();

  @override
  Node parse(BlockParser parser) {
    final currentLine = parser.current;
    final match = pattern.firstMatch(currentLine.content)!;
    final matchedText = match[0]!;
    final openMarker = match[1]!;
    final closeMarker = match[2];
    final level = openMarker.length;
    final openMarkerStart = matchedText.indexOf(openMarker);
    final openMarkerEnd = openMarkerStart + level;

    String rawContent;
    if (closeMarker == null) {
      rawContent = currentLine.content.substring(openMarkerEnd);
    } else {
      final closeMarkerStart = matchedText.lastIndexOf(closeMarker);
      rawContent = currentLine.content.substring(
        openMarkerEnd,
        closeMarkerStart,
      );
    }
    final leadingWhitespace = rawContent.length - rawContent.trimLeft().length;
    String? content = rawContent.trim();

    // https://spec.commonmark.org/0.30/#example-79
    if (closeMarker == null && RegExp(r'^#+$').hasMatch(content)) {
      content = null;
    }

    parser.advance();

    if (content == null) {
      return Element('h$level', const []);
    }

    final currentOffset = currentLine.offset;
    final contentOffsetMapper = currentOffset == null
        ? null
        : ContentOffsetMapper([
            Line(
              content,
              offset: currentOffset + openMarkerEnd + leadingWhitespace,
            ),
          ]);
    return Element('h$level', [UnparsedContent(content, contentOffsetMapper)]);
  }
}
