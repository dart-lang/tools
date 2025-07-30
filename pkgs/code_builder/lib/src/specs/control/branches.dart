// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// A [Conditional] branch.
///
/// Intentionally not exported to avoid confusion
/// with [Conditional].
///
@internal
abstract class Branch implements Built<Branch, BranchBuilder> {
  Branch._();
  factory Branch([void Function(BranchBuilder) updates]) = _$Branch;

  Expression? get condition;
  Block get body;

  _Branch _buildable(bool isElse) =>
      _Branch(condition: condition, body: body, isElse: isElse);
}

/// Builds a [Conditional] branch.
abstract class BranchBuilder implements Builder<Branch, BranchBuilder> {
  BranchBuilder._();
  factory BranchBuilder() = _$BranchBuilder;

  /// The `if` statement condition.
  ///
  /// If this is the first branch in a [Conditional], [condition] is
  /// required. Otherwise, it may be left `null` to create an `else` statement.
  Expression? condition;

  /// The branch body.
  BlockBuilder body = BlockBuilder();

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
      condition =
          ControlFlow.ifCase(object: object, pattern: pattern, guard: guard);
}

/// Buildable version of [Branch]
class _Branch extends _$Branch with ControlBlock {
  final bool isElse;

  _Branch({required super.condition, required super.body, required this.isElse})
      : super._();

  ControlExpression? get _condition =>
      condition == null ? null : ControlExpression.ifStatement(condition!);

  @override
  ControlExpression get _expression => isElse
      ? ControlExpression.elseStatement(_condition)
      : (_condition ?? throwError);

  Never get throwError {
    throw ArgumentError(
        'The first branch in a conditional must specify a condition',
        'condition');
  }
}

/// Represents a conditional (`if`/`else`) tree.
///
/// The first added branch will be treated as an `if` block, with
/// all subsequent conditions being treated as `else`.
///
/// {@category controlFlow}
abstract class Conditional
    with ControlTree
    implements Built<Conditional, ConditionalBuilder> {
  Conditional._();

  /// Build an [Conditional]
  factory Conditional(void Function(ConditionalBuilder tree) builder) =
      _$Conditional;

  @protected
  @visibleForTesting
  BuiltList<BranchBuilder> get branches;

  @override
  List<ControlBlock> get _blocks => branches
      .mapIndexed(
        (index, element) => element.build()._buildable(index != 0),
      )
      .toList();

  /// Builds a branch with [builder] and returns
  /// a new [Conditional] with it added to the tree.
  Conditional elseIf(void Function(BranchBuilder branch) builder) =>
      (toBuilder()..branches.add(BranchBuilder()..update(builder))).build();

  /// Builds a block with [builder] and returns a new [Conditional]
  /// with it added to the tree as an `else` [Branch].
  Conditional orElse(void Function(BlockBuilder body) builder) =>
      elseIf((block) => builder(block.body));
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
  ListBuilder<BranchBuilder> branches = ListBuilder();

  /// Build a branch with [builder] and add it to the conditional tree.
  ///
  /// The first branch will be an `if` block, and all subsequent branches
  /// will be `else if` or `else`.
  void add(void Function(BranchBuilder branch) builder) =>
      branches.add(BranchBuilder()..update(builder));

  /// Shorthand to build a block with no condition and add it to the tree.
  void addElse(void Function(BlockBuilder body) builder) =>
      branches.add(BranchBuilder()..body.update(builder));
}
