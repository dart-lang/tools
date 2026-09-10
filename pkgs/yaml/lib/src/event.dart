// Copyright (c) 2014, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'layout.dart';
import 'parser.dart';
import 'style.dart';
import 'yaml_document.dart';

/// An event emitted by a [Parser].
class Event {
  final EventType type;
  final FileSpan span;
  final List<LayoutElement> leadingLayout;
  final List<LayoutElement> trailingLayout;

  Event(
    this.type,
    this.span, {
    this.leadingLayout = const [],
    this.trailingLayout = const [],
  });

  @override
  String toString() => type.toString();
}

/// An event indicating the beginning of a YAML document.
class DocumentStartEvent extends Event {
  /// The document's `%YAML` directive, or `null` if there was none.
  final VersionDirective? versionDirective;

  /// The document's `%TAG` directives, if any.
  final List<TagDirective> tagDirectives;

  /// Whether the document started implicitly (that is, without an explicit
  /// `===` sequence).
  final bool isImplicit;

  DocumentStartEvent(
    FileSpan span, {
    this.versionDirective,
    List<TagDirective>? tagDirectives,
    this.isImplicit = true,
    super.leadingLayout,
    super.trailingLayout,
  })  : tagDirectives = tagDirectives ?? [],
        super(EventType.documentStart, span);

  @override
  String toString() => 'DOCUMENT_START';
}

/// An event indicating the end of a YAML document.
class DocumentEndEvent extends Event {
  /// Whether the document ended implicitly (that is, without an explicit
  /// `...` sequence).
  final bool isImplicit;

  DocumentEndEvent(
    FileSpan span, {
    this.isImplicit = true,
    super.leadingLayout,
    super.trailingLayout,
  }) : super(EventType.documentEnd, span);

  @override
  String toString() => 'DOCUMENT_END';
}

/// An event indicating that an alias was referenced.
class AliasEvent extends Event {
  /// The alias name.
  final String name;

  AliasEvent(
    FileSpan span,
    this.name, {
    super.leadingLayout,
    super.trailingLayout,
  }) : super(EventType.alias, span);

  @override
  String toString() => 'ALIAS $name';
}

/// An event that can have associated anchor and tag properties.
abstract class _ValueEvent extends Event {
  /// The name of the value's anchor, or `null` if it wasn't anchored.
  final String? anchor;

  /// The text of the value's tag, or `null` if it wasn't tagged.
  final String? tag;

  _ValueEvent(
    super.type,
    super.span, {
    this.anchor,
    this.tag,
    super.leadingLayout,
    super.trailingLayout,
  });

  @override
  String toString() {
    var buffer = StringBuffer('$type');
    if (anchor != null) buffer.write(' &$anchor');
    if (tag != null) buffer.write(' $tag');
    return buffer.toString();
  }
}

/// An event indicating a single scalar value.
class ScalarEvent extends _ValueEvent {
  /// The contents of the scalar.
  final String value;

  /// The style of the scalar in the original source.
  final ScalarStyle style;

  ScalarEvent(
    FileSpan span,
    this.value,
    this.style, {
    super.anchor,
    super.tag,
    super.leadingLayout,
    super.trailingLayout,
  }) : super(EventType.scalar, span);

  @override
  String toString() => '${super.toString()} "$value"';
}

/// An event indicating the beginning of a sequence.
class SequenceStartEvent extends _ValueEvent {
  /// The style of the collection in the original source.
  final CollectionStyle style;

  SequenceStartEvent(
    FileSpan span,
    this.style, {
    super.anchor,
    super.tag,
    super.leadingLayout,
    super.trailingLayout,
  }) : super(EventType.sequenceStart, span);
}

/// An event indicating the beginning of a mapping.
class MappingStartEvent extends _ValueEvent {
  /// The style of the collection in the original source.
  final CollectionStyle style;

  MappingStartEvent(
    FileSpan span,
    this.style, {
    super.anchor,
    super.tag,
    super.leadingLayout,
    super.trailingLayout,
  }) : super(EventType.mappingStart, span);
}

/// The types of [Event] objects.
enum EventType {
  streamStart,
  streamEnd,
  documentStart,
  documentEnd,
  alias,
  scalar,
  sequenceStart,
  sequenceEnd,
  mappingStart,
  mappingEnd
}
