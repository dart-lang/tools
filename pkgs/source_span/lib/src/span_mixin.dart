// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import 'highlighter.dart';
import 'span.dart';
import 'span_with_context.dart';
import 'utils.dart';

/// A mixin for easily implementing [SourceSpan].
///
/// This implements the [SourceSpan] methods in terms of [start], [end], and
/// [text]. This assumes that [start] and [end] have the same source URL, that
/// [start] comes before [end], and that [text] has a number of characters equal
/// to the distance between [start] and [end].
abstract class SourceSpanMixin implements SourceSpan {
  Uri get sourceUrl => start.sourceUrl;
  int get length => end.offset - start.offset;

  int compareTo(SourceSpan other) {
    var result = start.compareTo(other.start);
    return result == 0 ? end.compareTo(other.end) : result;
  }

  SourceSpan union(SourceSpan other) {
    if (sourceUrl != other.sourceUrl) {
      throw new ArgumentError("Source URLs \"${sourceUrl}\" and "
          " \"${other.sourceUrl}\" don't match.");
    }

    var start = min(this.start, other.start);
    var end = max(this.end, other.end);
    var beginSpan = start == this.start ? this : other;
    var endSpan = end == this.end ? this : other;

    if (beginSpan.end.compareTo(endSpan.start) < 0) {
      throw new ArgumentError("Spans $this and $other are disjoint.");
    }

    var text = beginSpan.text +
        endSpan.text.substring(beginSpan.end.distance(endSpan.start));
    return new SourceSpan(start, end, text);
  }

  String message(String message, {color}) {
    var buffer = new StringBuffer();
    buffer.write('line ${start.line + 1}, column ${start.column + 1}');
    if (sourceUrl != null) buffer.write(' of ${p.prettyUri(sourceUrl)}');
    buffer.write(': $message');

    var highlight = this.highlight(color: color);
    if (!highlight.isEmpty) {
      buffer.writeln();
      buffer.write(highlight);
    }

    return buffer.toString();
  }

  String highlight({color}) {
    if (this is! SourceSpanWithContext && this.length == 0) return "";
    return new Highlighter(this, color: color).highlight();
  }

  bool operator ==(other) =>
      other is SourceSpan && start == other.start && end == other.end;

  int get hashCode => start.hashCode + (31 * end.hashCode);

  String toString() => '<$runtimeType: from $start to $end "$text">';
}
