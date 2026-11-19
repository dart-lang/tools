// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// Lexical token stream access for YAML documents.
library;

import 'package:source_span/source_span.dart';

import 'src/error_listener.dart';
import 'src/loader.dart';
import 'src/token.dart';
import 'src/yaml_document.dart';
import 'src/yaml_exception.dart';
import 'src/yaml_node.dart';

/// Loads a single YAML document together with all non-empty lexical tokens
/// scanned from [yaml].
///
/// Behaves like `loadYamlDocument` from `package:yaml/yaml.dart`, except that
/// it also returns an unmodifiable list of all non-empty lexical tokens
/// (including comments, directives, structural indicators, anchors, tags,
/// aliases, and scalars) scanned from the entire [yaml] input, ordered by
/// ascending [FileSpan.start] offset.
///
/// The returned `tokens` cover the full input stream, including comments
/// outside `document.span` (such as leading or trailing document comments).
/// Tokens are non-overlapping except that a non-empty block scalar's span
/// includes any comment on its header line, which is also emitted as a
/// [YamlTokenKind.comment] token.
///
/// If [sourceUrl] is passed, it is used as the URL from which the YAML
/// originated for error reporting.
///
/// If [recover] is `true`, the loader attempts to recover from parse errors
/// and may return invalid or synthetic nodes. If [errorListener] is also
/// supplied, its [ErrorListener.onError] method is called for each error
/// recovered from. It is an error if [errorListener] is provided when
/// [recover] is `false`.
///
/// Throws a [YamlException] if [yaml] is malformed and [recover] is `false`,
/// or if [yaml] contains more than one document.
({YamlDocument document, List<YamlToken> tokens}) loadYamlDocumentWithTokens(
  String yaml, {
  Uri? sourceUrl,
  bool recover = false,
  ErrorListener? errorListener,
}) {
  final loader = Loader(
    yaml,
    sourceUrl: sourceUrl,
    recover: recover,
    retainTokens: true,
    errorListener: errorListener,
  );
  var document = loader.load();
  if (document == null) {
    document = YamlDocument.internal(
      YamlScalar.internalWithSpan(null, loader.span),
      loader.span,
      null,
      const [],
    );
  } else {
    final nextDocument = loader.load();
    if (nextDocument != null) {
      throw YamlException('Only expected one document.', nextDocument.span);
    }
  }
  final tokens = List<YamlToken>.unmodifiable(
    loader.tokens!
        .map((token) => YamlToken._(_kindFor(token.type), token.span)),
  );
  return (document: document, tokens: tokens);
}

/// A non-empty lexical token scanned from YAML source text.
final class YamlToken {
  /// The syntactic category of this token.
  final YamlTokenKind kind;

  /// The non-empty source span covered by this token in the input text.
  final FileSpan span;

  YamlToken._(this.kind, this.span);

  @override
  String toString() => '${kind.name}(${span.start.offset}..${span.end.offset})';
}

/// The syntactic category of a [YamlToken].
///
/// New token kinds may be added as static constants in minor releases.
final class YamlTokenKind {
  /// A `%YAML` version directive.
  static const versionDirective = YamlTokenKind._('versionDirective');

  /// A `%TAG` tag directive.
  static const tagDirective = YamlTokenKind._('tagDirective');

  /// An unrecognized `%...` directive.
  static const unknownDirective = YamlTokenKind._('unknownDirective');

  /// An explicit document start marker (`---`).
  static const documentStart = YamlTokenKind._('documentStart');

  /// An explicit document end marker (`...`).
  static const documentEnd = YamlTokenKind._('documentEnd');

  /// A flow sequence opening delimiter (`[`).
  static const flowSequenceStart = YamlTokenKind._('flowSequenceStart');

  /// A flow sequence closing delimiter (`]`).
  static const flowSequenceEnd = YamlTokenKind._('flowSequenceEnd');

  /// A flow mapping opening delimiter (`{`).
  static const flowMappingStart = YamlTokenKind._('flowMappingStart');

  /// A flow mapping closing delimiter (`}`).
  static const flowMappingEnd = YamlTokenKind._('flowMappingEnd');

  /// A block sequence entry indicator (`-`).
  static const blockEntry = YamlTokenKind._('blockEntry');

  /// A flow collection entry separator (`,`).
  static const flowEntry = YamlTokenKind._('flowEntry');

  /// An explicit mapping key indicator (`?`).
  static const key = YamlTokenKind._('key');

  /// A mapping value indicator (`:`).
  static const value = YamlTokenKind._('value');

  /// An alias (`*name`).
  static const alias = YamlTokenKind._('alias');

  /// An anchor (`&name`).
  static const anchor = YamlTokenKind._('anchor');

  /// A node tag (`!tag` or `!<uri>`).
  static const tag = YamlTokenKind._('tag');

  /// A scalar value.
  static const scalar = YamlTokenKind._('scalar');

  /// A comment (`# ...`), excluding the terminating line break.
  static const comment = YamlTokenKind._('comment');

  /// A human-readable name for this token kind.
  final String name;

  const YamlTokenKind._(this.name);

  @override
  String toString() => 'YamlTokenKind.$name';
}

YamlTokenKind _kindFor(TokenType type) => switch (type) {
      TokenType.versionDirective => YamlTokenKind.versionDirective,
      TokenType.tagDirective => YamlTokenKind.tagDirective,
      TokenType.unknownDirective => YamlTokenKind.unknownDirective,
      TokenType.documentStart => YamlTokenKind.documentStart,
      TokenType.documentEnd => YamlTokenKind.documentEnd,
      TokenType.flowSequenceStart => YamlTokenKind.flowSequenceStart,
      TokenType.flowSequenceEnd => YamlTokenKind.flowSequenceEnd,
      TokenType.flowMappingStart => YamlTokenKind.flowMappingStart,
      TokenType.flowMappingEnd => YamlTokenKind.flowMappingEnd,
      TokenType.blockEntry => YamlTokenKind.blockEntry,
      TokenType.flowEntry => YamlTokenKind.flowEntry,
      TokenType.key => YamlTokenKind.key,
      TokenType.value => YamlTokenKind.value,
      TokenType.alias => YamlTokenKind.alias,
      TokenType.anchor => YamlTokenKind.anchor,
      TokenType.tag => YamlTokenKind.tag,
      TokenType.scalar => YamlTokenKind.scalar,
      TokenType.comment => YamlTokenKind.comment,
      TokenType.streamStart ||
      TokenType.streamEnd ||
      TokenType.blockSequenceStart ||
      TokenType.blockMappingStart ||
      TokenType.blockEnd =>
        throw StateError(
            'Zero-length structural token $type cannot be retained'),
    };
