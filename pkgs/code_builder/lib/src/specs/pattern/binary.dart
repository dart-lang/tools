// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A binary logical pattern (`||` or `&&`).
class BinaryPattern extends Pattern {
  final Pattern left;
  final Pattern right;
  final String operator;

  const BinaryPattern._(this.left, this.right, this.operator);

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitBinaryPattern(this, context);
}

/// A parenthesized pattern `(pattern)`.
class ParenthesizedPattern extends Pattern {
  final Pattern pattern;

  const ParenthesizedPattern._(this.pattern);

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitParenthesizedPattern(this, context);
}
