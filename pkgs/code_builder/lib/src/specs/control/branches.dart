// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a [Conditional] branch.
abstract class Branch with ControlBody implements Built<Branch, BranchBuilder> {
  Branch._();

  /// Builds a [Branch]
  factory Branch([void Function(BranchBuilder branch) updates]) = _$Branch;

  /// Builds a [Branch] from [condition] and [body]
  factory Branch.from(Expression? condition, Code? body) => Branch(
    (branch) =>
        branch
          ..body = body
          ..condition = condition,
  );

  /// The `if` statement condition.
  Expression? get condition;

  /// Builds a [Conditional] containing only this branch.
  Conditional get asConditional => Conditional.from([this]);
}

/// Builds a [Conditional] branch.
abstract class BranchBuilder
    with ControlBodyBuilder
    implements Builder<Branch, BranchBuilder> {
  BranchBuilder._();
  factory BranchBuilder() = _$BranchBuilder;

  /// The `if` statement condition.
  ///
  /// If this is the first branch in a [Conditional], [condition] is
  /// required. Otherwise, it may be left `null` to create an `else` statement.
  Expression? condition;

  /// The branch body.
  @override
  // ignore: overridden_fields
  Code? body;

  /// Set [condition] to an `if-case` expression, matching [object] against
  /// [pattern].
  ///
  /// Guard clause [guard] can also be specified.
  ///
  /// ```dart
  /// if (object case pattern)
  /// if (object case pattern when guard)
  /// ```
  ///
  /// Equivalent to using [ControlFlow.ifCase].
  void ifCase({
    required Expression object,
    required Expression pattern,
    Expression? guard,
  }) =>
      condition = ControlFlow.ifCase(
        object: object,
        pattern: pattern,
        guard: guard,
      );
}

/// Represents a conditional (`if`/`else`) tree.
///
/// The first added [Branch] will be treated as an `if` block, with
/// all subsequent conditions being treated as `else`.
///
/// {@category controlFlow}
abstract class Conditional
    implements Built<Conditional, ConditionalBuilder>, Code, Spec {
  Conditional._();

  /// Build a [Conditional]
  factory Conditional(void Function(ConditionalBuilder tree) builder) =
      _$Conditional;

  /// Build a conditional from [branches]
  factory Conditional.from(Iterable<Branch> branches) =>
      Conditional((tree) => tree.branches.addAll(branches));

  BuiltList<Branch> get branches;

  /// Returns a new [Conditional] with [branch] added to the tree.
  Conditional elseIf(Branch branch) =>
      (toBuilder()..branches.add(branch)).build();

  /// Returns a new [Conditional] with [code] added to the tree
  /// as an `else` [Branch].
  Conditional orElse(Code? code) => elseIf(Branch((b) => b.body = code));

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitConditional(this, context);
}

/// Builds a [Conditional].
///
/// The first added branch will be treated as an `if` block, with
/// all subsequent conditions being treated as `else`.
///
/// {@category controlFlow}
abstract class ConditionalBuilder
    implements Builder<Conditional, ConditionalBuilder> {
  ConditionalBuilder._();
  factory ConditionalBuilder() = _$ConditionalBuilder;

  /// The items in this tree.
  ListBuilder<Branch> branches = ListBuilder();

  /// Add [branch] to the conditional tree.
  ///
  /// The first branch will be an `if` block, and all subsequent branches
  /// will be `else if` or `else`.
  void add(Branch branch) => branches.add(branch);

  /// Shorthand to add a branch with no condition to the tree.
  void addElse(Code? body) =>
      branches.add(Branch((branch) => branch.body = body));
}
