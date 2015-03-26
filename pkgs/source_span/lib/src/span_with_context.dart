// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library source_span.span;

import 'location.dart';
import 'span.dart';

/// A class that describes a segment of source text with additional context.
class SourceSpanWithContext extends SourceSpanBase {
  /// Text around the span, which includes the line containing this span.
  final String context;

  /// Creates a new span from [start] to [end] (exclusive) containing [text], in
  /// the given [context].
  ///
  /// [start] and [end] must have the same source URL and [start] must come
  /// before [end]. [text] must have a number of characters equal to the
  /// distance between [start] and [end]. [context] must contain [text], and
  /// [text] should start at `start.column` from the beginning of a line in
  /// [context].
  SourceSpanWithContext(
      SourceLocation start, SourceLocation end, String text, this.context)
      : super(start, end, text) {
    var index = context.indexOf(text);
    if (index == -1) {
      throw new ArgumentError(
          'The context line "$context" must contain "$text".');
    }

    var beginningOfLine = context.lastIndexOf('\n', index) + 1;
    if (start.column != index - beginningOfLine) {
      throw new ArgumentError('The span text "$text" must start at '
          'column ${start.column + 1} in a line within "$context".');
    }
  }
}
