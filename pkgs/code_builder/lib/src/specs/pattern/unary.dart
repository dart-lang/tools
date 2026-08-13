// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A unary postfix pattern (`?` or `!`).
class UnaryPattern extends Pattern {
  final Pattern pattern;
  final String operator;

  const UnaryPattern._(this.pattern, this.operator);

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitUnaryPattern(this, context);
}

/// A cast pattern `pattern as type`.
class CastPattern extends Pattern {
  final Pattern pattern;
  final Reference type;

  const CastPattern._(this.pattern, this.type);

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitCastPattern(this, context);
}
