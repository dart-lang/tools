// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'layout.dart';
import 'scanner.dart';
import 'style.dart';

/// A token emitted by a [Scanner].
class Token {
  final TokenType type;
  final FileSpan span;
  final List<LayoutElement> leadingLayout;
  final List<LayoutElement> trailingLayout;

  Token(
    this.type,
    this.span, {
    this.leadingLayout = const [],
    List<LayoutElement>? trailingLayout,
  }) : trailingLayout = trailingLayout ?? [];

  @override
  String toString() => type.toString();
}

/// A token representing a `%YAML` directive.
class VersionDirectiveToken extends Token {
  /// The declared major version of the document.
  final int major;

  /// The declared minor version of the document.
  final int minor;

  VersionDirectiveToken(FileSpan span, this.major, this.minor,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.versionDirective, span);

  @override
  String toString() => 'VERSION_DIRECTIVE $major.$minor';
}

/// A token representing a `%TAG` directive.
class TagDirectiveToken extends Token {
  /// The tag handle used in the document.
  final String handle;

  /// The tag prefix that the handle maps to.
  final String prefix;

  TagDirectiveToken(FileSpan span, this.handle, this.prefix,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.tagDirective, span);

  @override
  String toString() => 'TAG_DIRECTIVE $handle $prefix';
}

/// A token representing an anchor (`&foo`).
class AnchorToken extends Token {
  final String name;

  AnchorToken(FileSpan span, this.name,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.anchor, span);

  @override
  String toString() => 'ANCHOR $name';
}

/// A token representing an alias (`*foo`).
class AliasToken extends Token {
  final String name;

  AliasToken(FileSpan span, this.name,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.alias, span);

  @override
  String toString() => 'ALIAS $name';
}

/// A token representing a tag (`!foo`).
class TagToken extends Token {
  /// The tag handle for named tags.
  final String? handle;

  /// The tag suffix.
  final String suffix;

  TagToken(FileSpan span, this.handle, this.suffix,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.tag, span);

  @override
  String toString() => 'TAG $handle $suffix';
}

/// A scalar value.
class ScalarToken extends Token {
  /// The unparsed contents of the value..
  final String value;

  /// The style of the scalar in the original source.
  final ScalarStyle style;

  ScalarToken(FileSpan span, this.value, this.style,
      {super.leadingLayout, super.trailingLayout})
      : super(TokenType.scalar, span);

  @override
  String toString() => 'SCALAR $style "$value"';
}

/// The types of [Token] objects.
enum TokenType {
  streamStart,
  streamEnd,

  versionDirective,
  tagDirective,
  documentStart,
  documentEnd,

  blockSequenceStart,
  blockMappingStart,
  blockEnd,

  flowSequenceStart,
  flowSequenceEnd,
  flowMappingStart,
  flowMappingEnd,

  blockEntry,
  flowEntry,
  key,
  value,

  alias,
  anchor,
  tag,
  scalar
}
