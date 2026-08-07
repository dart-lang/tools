// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A list pattern `[p1, p2, ...rest]`.
class ListPattern extends Pattern {
  final List<Pattern> elements;
  final Reference? type;
  final Pattern? rest;
  final int? restIndex;

  const ListPattern._(this.elements, {this.type, this.rest, this.restIndex});

  bool get hasRest => rest != null || restIndex != null;

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitListPattern(this, context);
}

/// An entry in a [MapPattern].
class MapPatternEntry {
  final Expression key;
  final Pattern value;

  const MapPatternEntry(this.key, this.value);
}

/// A map pattern `{'key': pattern}`.
class MapPattern extends Pattern {
  final List<MapPatternEntry> entries;
  final Reference? keyType;
  final Reference? valueType;

  const MapPattern._(this.entries, {this.keyType, this.valueType});

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitMapPattern(this, context);
}

/// A record destructuring pattern `(p1, name: p2)`.
class RecordPattern extends Pattern {
  final List<Pattern> positional;
  final Map<String, Pattern> named;

  const RecordPattern._({this.positional = const [], this.named = const {}});

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitRecordPattern(this, context);
}

/// An object destructuring pattern `SomeClass(p1, name: p2)`.
class ObjectPattern extends Pattern {
  final Reference type;
  final List<Pattern> positional;
  final Map<String, Pattern> named;

  const ObjectPattern._(
    this.type, {
    this.positional = const [],
    this.named = const {},
  });

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitObjectPattern(this, context);
}
