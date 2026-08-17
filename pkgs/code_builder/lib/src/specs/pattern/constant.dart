// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A constant pattern matching a constant [expression].
class ConstantPattern extends Pattern {
  final Expression expression;
  final bool isConst;

  const ConstantPattern._(this.expression, {this.isConst = false});

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitConstantPattern(this, context);
}
