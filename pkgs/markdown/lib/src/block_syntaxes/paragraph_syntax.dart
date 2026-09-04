// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../block_parser.dart';
import '../line.dart';
import '../patterns.dart';
import 'block_syntax.dart';
import 'setext_header_syntax.dart';

/// Parses paragraphs of regular text.
class ParagraphSyntax extends BlockSyntax {
  @override
  RegExp get pattern => dummyPattern;

  @override
  bool canEndBlock(BlockParser parser) => false;

  const ParagraphSyntax();

  @override
  bool canParse(BlockParser parser) => true;

  @override
  Node? parse(BlockParser parser) {
    final childLines = <Line>[parser.current];

    parser.advance();
    var interruptedBySetextHeading = false;
    // Eat until we hit something that ends a paragraph.
    while (!parser.isDone) {
      final syntax = interruptedBy(parser);
      if (syntax != null) {
        interruptedBySetextHeading = syntax is SetextHeaderSyntax;
        break;
      }
      childLines.add(parser.current);
      parser.advance();
    }

    // It is not a paragraph, but a setext heading.
    if (interruptedBySetextHeading) {
      return null;
    }

    final text = childLines.map((line) => line.content).join('\n');
    final contents = UnparsedContent(
      text.trimRight(),
      ContentOffsetMapper(childLines),
    );
    return Element('p', [contents]);
  }
}
