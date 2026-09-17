// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'style.dart';

/// A lexical token emitted by the YAML scanner.
class Token {
  /// The syntactic category of this token.
  final TokenType type;

  /// The source span covered by this token in the input text.
  final FileSpan span;

  /// Creates a token of [type] covering [span].
  Token(this.type, this.span);

  @override
  String toString() => type.toString();
}

/// A token representing a `%YAML` directive.
final class VersionDirectiveToken implements Token {
  @override
  TokenType get type => TokenType.versionDirective;
  @override
  final FileSpan span;

  /// The declared major version of the document.
  final int major;

  /// The declared minor version of the document.
  final int minor;

  /// Creates a `%YAML` directive token covering [span] with version
  /// `[major].[minor]`.
  VersionDirectiveToken(this.span, this.major, this.minor);

  @override
  String toString() => 'VERSION_DIRECTIVE $major.$minor';
}

/// A token representing a `%TAG` directive.
final class TagDirectiveToken implements Token {
  @override
  TokenType get type => TokenType.tagDirective;
  @override
  final FileSpan span;

  /// The tag handle used in the document (for example, `!` or `!!`).
  final String handle;

  /// The tag prefix that [handle] maps to.
  final String prefix;

  /// Creates a `%TAG` directive token covering [span] mapping [handle] to
  /// [prefix].
  TagDirectiveToken(this.span, this.handle, this.prefix);

  @override
  String toString() => 'TAG_DIRECTIVE $handle $prefix';
}

/// A token representing an anchor (`&name`).
final class AnchorToken implements Token {
  @override
  TokenType get type => TokenType.anchor;
  @override
  final FileSpan span;

  /// The anchor name (without the leading `&`).
  final String name;

  /// Creates an anchor token covering [span] for anchor [name].
  AnchorToken(this.span, this.name);

  @override
  String toString() => 'ANCHOR $name';
}

/// A token representing an alias (`*name`).
final class AliasToken implements Token {
  @override
  TokenType get type => TokenType.alias;
  @override
  final FileSpan span;

  /// The referenced anchor name (without the leading `*`).
  final String name;

  /// Creates an alias token covering [span] referencing anchor [name].
  AliasToken(this.span, this.name);

  @override
  String toString() => 'ALIAS $name';
}

/// A token representing a node tag (`!tag` or `!<uri>`).
final class TagToken implements Token {
  @override
  TokenType get type => TokenType.tag;
  @override
  final FileSpan span;

  /// The tag handle for named tags, or `null` for verbatim tags.
  final String? handle;

  /// The tag suffix following [handle], or the full verbatim URI.
  final String suffix;

  /// Creates a tag token covering [span] with optional [handle] and [suffix].
  TagToken(this.span, this.handle, this.suffix);

  @override
  String toString() => 'TAG $handle $suffix';
}

/// A token representing a scalar value.
final class ScalarToken implements Token {
  @override
  TokenType get type => TokenType.scalar;
  @override
  final FileSpan span;

  /// The unparsed string contents of the scalar value.
  final String value;

  /// The syntactic style of the scalar in the original source.
  final ScalarStyle style;

  /// Creates a scalar token covering [span] with decoded string [value] and
  /// source [style].
  ScalarToken(this.span, this.value, this.style);

  @override
  String toString() => 'SCALAR $style "$value"';
}

/// A token representing a comment (`# ...`).
final class CommentToken implements Token {
  @override
  TokenType get type => TokenType.comment;
  @override
  final FileSpan span;

  /// Creates a comment token covering [span], starting at `#` through the end
  /// of the comment text (excluding the terminating line break).
  CommentToken(this.span);

  @override
  String toString() => 'COMMENT "${span.text}"';
}

/// The syntactic categories of [Token] objects emitted by the YAML scanner.
enum TokenType {
  /// The start of a YAML stream.
  streamStart,

  /// The end of a YAML stream.
  streamEnd,

  /// A `%YAML` version directive.
  versionDirective,

  /// A `%TAG` tag directive.
  tagDirective,

  /// An explicit document start marker (`---`).
  documentStart,

  /// An explicit document end marker (`...`).
  documentEnd,

  /// The start of a block sequence.
  blockSequenceStart,

  /// The start of a block mapping.
  blockMappingStart,

  /// The end of a block collection.
  blockEnd,

  /// A flow sequence opening delimiter (`[`).
  flowSequenceStart,

  /// A flow sequence closing delimiter (`]`).
  flowSequenceEnd,

  /// A flow mapping opening delimiter (`{`).
  flowMappingStart,

  /// A flow mapping closing delimiter (`}`).
  flowMappingEnd,

  /// A block sequence entry indicator (`-`).
  blockEntry,

  /// A flow collection entry separator (`,`).
  flowEntry,

  /// An explicit mapping key indicator (`?`).
  key,

  /// A mapping value indicator (`:`).
  value,

  /// An alias indicator and name (`*name`).
  alias,

  /// An anchor indicator and name (`&name`).
  anchor,

  /// A tag (`!tag`).
  tag,

  /// A scalar value.
  scalar,

  /// A comment (`# ...`).
  comment
}
