// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

/// A non-semantic source layout element (comment, whitespace, or newline)
/// preserved during parsing when layout retention is enabled.
sealed class LayoutElement {
  /// The source span of this layout element.
  SourceSpan get span;

  /// The text content of this layout element.
  String get text => span.text;
}

/// A comment in a YAML source document (`# ...`).
final class CommentElement extends LayoutElement {
  @override
  final SourceSpan span;

  /// Whether this comment appears on the same line following content
  /// (`true`, trailing comment) or on its own line / preceding content
  /// (`false`, leading comment).
  final bool isTrailing;

  CommentElement(this.span, {this.isTrailing = false});

  @override
  String toString() => 'Comment("${span.text}", trailing: $isTrailing)';
}

/// A sequence of horizontal whitespace characters (spaces or tabs).
final class WhitespaceElement extends LayoutElement {
  @override
  final SourceSpan span;

  WhitespaceElement(this.span);

  @override
  String toString() => 'Whitespace(${span.length})';
}

/// A line break (`\n`, `\r\n`, or `\r`).
final class NewlineElement extends LayoutElement {
  @override
  final SourceSpan span;

  NewlineElement(this.span);

  @override
  String toString() => 'Newline';
}
