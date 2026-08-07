// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../pattern.dart';

/// A variable pattern binding [name].
class VariablePattern extends Pattern {
  final String name;
  final Reference? type;
  final bool isFinal;
  final bool isVar;

  const VariablePattern._(
    this.name, {
    this.type,
    this.isFinal = false,
    this.isVar = false,
  });

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitVariablePattern(this, context);
}

/// A wildcard pattern `_`.
class WildcardPattern extends Pattern {
  const WildcardPattern._();

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]) =>
      visitor.visitWildcardPattern(this, context);
}
