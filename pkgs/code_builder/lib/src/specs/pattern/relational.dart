// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A relational pattern (`==`, `!=`, `<`, `>`, `<=`, `>=`).
class RelationalPattern extends Pattern {
  final String operator;
  final Expression operand;

  const RelationalPattern._(this.operator, this.operand);

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitRelationalPattern(this, context);
}
