// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a single `if` block.
///
/// Use [IfTree] to create a tree of `if`, `else if`,
/// and `else` statements.
///
/// {@category controlFlow}
abstract class Condition
    with ControlBlock
    implements Built<Condition, ConditionBuilder> {
  Condition._();
  factory Condition(void Function(ConditionBuilder block) builder) =
      _$Condition;

  /// The statement condition.
  ///
  /// Required if this is a standalone [Condition] or
  /// the first in an [IfTree], otherwise optional.
  Expression? get condition;

  ControlExpression? get _statement =>
      condition == null ? null : ControlExpression.ifStatement(condition!);

  @override
  ControlExpression get _expression =>
      _statement ??
      (throw ArgumentError(
          'A condition must be provided with an `if` statement', 'condition'));

  /// This condition as an `else` block.
  ///
  /// Will be `else` if [condition] is `null`,
  /// otherwise `else if`.
  Condition get asElse => ElseCondition(this);

  /// Returns an [IfTree] with just this [Condition].
  IfTree get asTree => IfTree.of([this]);
}

/// Builds a [Condition].
///
/// {@category controlFlow}
abstract class ConditionBuilder
    implements Builder<Condition, ConditionBuilder> {
  ConditionBuilder._();
  factory ConditionBuilder() = _$ConditionBuilder;

  BlockBuilder body = BlockBuilder();
  Expression? condition;

  /// Sets [condition] to an `if-case` expression.
  ///
  /// Uses [ControlFlow.ifCase] to create the expression.
  ///
  /// The expression will take the form:
  /// ```dart
  /// object case pattern
  /// ```
  ///
  /// Optionally set a guard (`when`) clause with [guard]:
  /// ```dart
  /// object case pattern when guard
  /// ```
  ///
  /// See https://dart.dev/language/branches#if-case
  void ifCase({
    required Expression object,
    required Expression pattern,
    Expression? guard,
  }) {
    condition =
        ControlFlow.ifCase(object: object, pattern: pattern, guard: guard);
  }
}

/// A [condition] preceded by `else`
@internal
@visibleForTesting
class ElseCondition extends _$Condition {
  ElseCondition(Condition condition)
      : super._(body: condition.body, condition: condition.condition);

  @override
  ControlExpression get _expression =>
      ControlExpression.elseStatement(_statement);
}

/// Represents an `if`/`else` tree.
///
/// The first [Condition]  in [blocks] will be treated as an `if`
/// block. All subsequent conditions will be treated as `else` blocks
/// using [Condition.asElse].
///
/// {@category controlFlow}
abstract class IfTree with ControlTree implements Built<IfTree, IfTreeBuilder> {
  IfTree._();

  /// Build an [IfTree]
  factory IfTree(void Function(IfTreeBuilder tree) builder) = _$IfTree;

  /// Create an [IfTree] from a list of [conditions].
  factory IfTree.of(Iterable<Condition> conditions) => IfTree(
        (tree) {
          tree.addAll(conditions);
        },
      );

  /// Called when an [IfTreeBuilder] is built.
  ///
  /// Replaces all but the first block with an [ElseCondition]
  ///
  @BuiltValueHook(finalizeBuilder: true)
  static void _build(IfTreeBuilder builder) {
    if (builder.blocks.isEmpty) return;

    final first = builder.blocks.first;
    builder.blocks
      ..skip(1)
      ..map((b) => b.asElse)
      ..insert(0, first);
  }

  BuiltList<Condition> get blocks;

  @override
  List<ControlBlock> get _blocks => blocks.toList();

  /// Returns a new [IfTree] with [condition] added.
  IfTree withCondition(Condition condition) =>
      (toBuilder()..add(condition)).build();

  /// Builds a [Condition] with [builder] and returns
  /// a new [IfTree] with it added.
  IfTree elseIf(void Function(ConditionBuilder block) builder) =>
      withCondition((ConditionBuilder()..update(builder)).build());

  /// Builds a block with [builder] and returns a new [IfTree]
  /// with it added as an `else` [Condition].
  IfTree orElse(void Function(BlockBuilder body) builder) => elseIf(
        (block) {
          builder(block.body);
        },
      );
}

/// Builds an [IfTree].
///
/// {@category controlFlow}
abstract class IfTreeBuilder implements Builder<IfTree, IfTreeBuilder> {
  IfTreeBuilder._();
  factory IfTreeBuilder() = _$IfTreeBuilder;

  /// The items in this tree.
  ListBuilder<Condition> blocks = ListBuilder();

  /// Build a [Condition] with [builder] and add it to the tree.
  ///
  /// Shorthand for calling `add` and creating a condition
  void ifThen(void Function(ConditionBuilder block) builder) =>
      add((ConditionBuilder()..update(builder)).build());

  /// Add a [Condition] to the tree.
  ///
  /// Shorthand for `blocks.add`
  void add(Condition condition) => blocks.add(condition);

  /// Add multiple [Condition]s to the tree.
  ///
  /// Shorthand for `blocks.addAll`
  void addAll(Iterable<Condition> conditions) => blocks.addAll(conditions);

  /// Builds a block using [builder] and adds it to the tree
  /// as an `else` [Condition].
  ///
  /// Shorthand for calling [add] and creating an `else` condition.
  void orElse(void Function(BlockBuilder body) builder) => add(Condition(
        (block) {
          builder(block.body);
        },
      ));

  /// Shorthand to add an `else` statement that throws [expression].
  void orElseThrow(Expression expression) => orElse(
        (body) {
          body.addExpression(expression.thrown);
        },
      );
}
