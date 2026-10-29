// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import 'inline_syntax.dart';

/// Represents a hard line break.
class LineBreakSyntax extends InlineSyntax {
  LineBreakSyntax() : super(r'(?:\\|  +)\n');

  @override
  bool tryMatch(InlineParser parser, [int? startMatchPos]) {
    final pos = startMatchPos ?? parser.pos;
    if (pos > parser.start &&
        parser.charAt(pos) == $space &&
        parser.charAt(pos - 1) == $space) {
      return false;
    }
    return super.tryMatch(parser, startMatchPos);
  }

  /// Create a void <br> element.
  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(Element.empty('br'));
    return true;
  }
}
