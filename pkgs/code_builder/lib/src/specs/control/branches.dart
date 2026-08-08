// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A condition in a [Branch] (`if` or `else if`).
abstract class Condition implements Spec {
  const Condition();

  /// A boolean expression condition: `if (expression)`.
  static BooleanCondition expression(Expression expression) =>
      BooleanCondition._(expression);

  /// An if-case pattern matching condition: `if (object case pattern [when guard])`.
  static CaseCondition ifCase(
    Expression object,
    Pattern pattern, {
    Expression? guard,
  }) => CaseCondition._(object, pattern, guard: guard);
}

/// A boolean expression condition.
class BooleanCondition extends Condition {
  final Expression expression;

  const BooleanCondition._(this.expression);

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitBooleanCondition(this, context);
}

/// An `if-case` condition: `object case pattern [when guard]`.
class CaseCondition extends Condition {
  final Expression object;
  final Pattern pattern;
  final Expression? guard;

  const CaseCondition._(this.object, this.pattern, {this.guard});

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitCaseCondition(this, context);
}

/// A branch within a [Conditional] (`if` or `else if`).
abstract class Branch implements Built<Branch, BranchBuilder> {
  factory Branch([void Function(BranchBuilder) updates]) = _$Branch;

  Branch._();

  /// The condition for this branch.
  Condition get condition;

  /// The body of this branch.
  Code? get body;
}

abstract class BranchBuilder implements Builder<Branch, BranchBuilder> {
  factory BranchBuilder() = _$BranchBuilder;
  BranchBuilder._();

  Condition? condition;
  Code? body;
}

/// An `if`/`else if`/`else` conditional statement.
abstract class Conditional
    implements Built<Conditional, ConditionalBuilder>, Code, Spec {
  factory Conditional([void Function(ConditionalBuilder) updates]) =
      _$Conditional;

  Conditional._() {
    if (branches.isEmpty) {
      throw ArgumentError.value(
        branches,
        'branches',
        'A conditional must have at least one branch.',
      );
    }
  }

  /// The `if` and `else if` branches in this conditional.
  ///
  /// The first branch is emitted as `if (condition) { body }`, and any
  /// subsequent branches are emitted as `else if (condition) { body }`.
  BuiltList<Branch> get branches;

  /// The optional `else` body.
  Code? get orElse;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitConditional(this, context);
}

abstract class ConditionalBuilder
    implements Builder<Conditional, ConditionalBuilder> {
  factory ConditionalBuilder() = _$ConditionalBuilder;
  ConditionalBuilder._();

  ListBuilder<Branch> branches = ListBuilder<Branch>();
  Code? orElse;
}
