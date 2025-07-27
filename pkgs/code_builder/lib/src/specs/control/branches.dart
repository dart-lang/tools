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

/// A `switch` case used in either a [SwitchStatement] or a [SwitchExpression].
///
/// The case type is determined by the generic parameter [T], which defines
/// the type of [body] required.
///
/// For `switch` *statements*, [T] should be [Code] (e.g. a [Block]).
/// Bodies may be multi-line, and may also be left `null` to use case
/// fall-through. Additionally, labels are supported via [label].
///
/// ```dart
/// case pattern:
/// case pattern when guard:
///   body;
///
/// label:
/// case pattern:
///   body;
///   body;
/// ```
///
/// For `switch` *expressions*, [T] must be a non-null [Expression].
/// Fall-though is not supported in `switch` expressions, nor are labels.
/// Attempting to use fall-through by leaving [body] null will throw an
/// [ArgumentError], and setting [label] will have no effect.
///
/// ```dart
/// pattern => body,
/// pattern when guard => body,
/// ```
///
/// {@category controlFlow}
abstract class Case<T> implements Built<Case<T>, CaseBuilder<T>> {
  Case._();

  /// Build a new [Case].
  factory Case([void Function(CaseBuilder<T>) updates]) = _$Case<T>;

  /// Create a catch-all case, either `default` or wildcard (`_`).
  ///
  /// For [SwitchStatement], the `default` keyword will be used. [label] will be
  /// respected, if provided. To force use of the wildcard expression
  /// instead, use [Case.new] with [ControlFlow.wildcard] as the pattern.
  ///
  /// For [SwitchExpression], a wildcard case will be created, as `switch`
  /// expressions don't support `default`. [label] will be ignored.
  factory Case.any(T body, {String? label}) = DefaultCase._;

  /// The pattern to match.
  Expression get pattern;

  /// The optional guard (`when`) clause.
  Expression? get guard;

  /// An optional label for this case.
  ///
  /// **NOTE:** Only `switch` *statements* ([SwitchStatement]) support labels.
  /// Setting [label] with `switch` *expressions* ([SwitchExpression]) has no
  /// effect; the label will be silently ignored.
  String? get label;

  /// Whether or not to use the `default` keyword
  bool get _default => false;

  /// The body of this case.
  ///
  /// May be left null when used in a [SwitchStatement] to use case
  /// fall-through.
  ///
  /// May **not** be left null in a [SwitchExpression], as they do not support
  /// fall-through. Will throw an [ArgumentError] if left unset.
  //* T must be nullable, otherwise built_value will perform a check that it was
  //* actually set, causing an error when left null to use fallthrough. Instead,
  //* it is up to the buildable case implementations (see below) to validate
  //* this value.
  T? get body;
}

/// **INTERNAL**
/// Case with `default` keyword
@internal
class DefaultCase<T> extends _$Case<T> {
  DefaultCase._(T body, {super.label})
      : super._(body: body, pattern: ControlFlow.wildcard);

  @override
  bool get _default => true;
}

/// **INTERNAL**
/// Buildable case statement
@internal
class CaseStatement extends _$Case<Code?> implements Code {
  final Case<Code?> item;

  CaseStatement._(this.item)
      : super._(
            pattern: item.pattern,
            body: item.body,
            guard: item.guard,
            label: item.label);

  @override
  bool get _default => item._default;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitCaseStatement(this, context);
}

/// **INTERNAL**
///
/// Base class for `switch` types.
///
@internal
@optionalTypeArgs
abstract class Switch<T> implements Code, Spec {
  /// The value being matched against.
  ///
  /// ```dart
  /// switch (value) {
  ///   ...
  /// }
  /// ```
  Expression get value;

  /// The cases in the `switch` body.
  BuiltList<Case<T>> get cases;

  // non-abstract so that built_value ignores it
  /// Convert generic [Case] into an implementation-specific buildable
  /// subtype.
  Iterable<Code> get _cases =>
      throw UnsupportedError('Must be implemented by subclasses');
}

/// **INTERNAL**
///
/// Base class for `switch` builders
///
@internal
@optionalTypeArgs
abstract class SwitchBuilder<T> {
  /// The value being matched against.
  ///
  /// ```dart
  /// switch (value) {
  ///   ...
  /// }
  /// ```
  Expression? value;

  /// The cases in the `switch` body.
  ListBuilder<Case<T>> cases = ListBuilder();
}

/// **INTERNAL**
///
/// A buildable switch class. [Switch] subtypes are converted into
/// this by [ControlBlockVisitor.visitSwitch] in order to be built.
///
@internal
@optionalTypeArgs
class BuildableSwitch<T> with ControlBlock {
  final Expression value;
  final Iterable<Code> cases;

  BuildableSwitch({required this.value, required this.cases});

  @override
  ControlExpression get _expression => ControlExpression.switchStatement(value);

  @override
  Block get body => Block.of(cases);
}

/// Common [accept] implementation for [Switch] subtypes
mixin _SwitchImpl {
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      // can't be `on Switch` because built_value classes can't extend
      // anything but `Object`, and even though switch subtypes implement
      // `Switch`, they must extend `Switch` instead in order to be allowed
      // to use a mixin `on Switch`. as a workaround, we are casting this
      // as a switch, which will always work because this mixin will only
      // ever be used on switch subtypes (hence why it's private).
      visitor.visitSwitch(this as Switch, context);
}

abstract class SwitchStatement
    with _SwitchImpl
    implements Switch<Code?>, Built<SwitchStatement, SwitchStatementBuilder> {
  SwitchStatement._();
  factory SwitchStatement([void Function(SwitchStatementBuilder) updates]) =
      _$SwitchStatement;

  @override
  Iterable<Code> get _cases => cases.map(CaseStatement._);
}
