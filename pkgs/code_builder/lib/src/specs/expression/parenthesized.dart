// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// An [Expression] wrapped with parenthesis.
class ParenthesizedExpression extends Expression {
  final Expression inner;

  const ParenthesizedExpression._(this.inner);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitParenthesizedExpression(this, context);
}
