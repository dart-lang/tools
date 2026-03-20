// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// **INTERNAL**
///
/// Represents a control expression.
///
/// {@category controlFlow}
@internal
class ControlExpression extends Expression {
  /// The control statement (e.g. `if`, `for`).
  final String control;

  /// Zero or more expressions that make up this control
  /// expression's body.
  ///
  /// If multiple expressions are provided, they will be
  /// separated with [separator].
  ///
  /// If [parenthesised] is `true`, the whole body will be
  /// wrapped in parenthesis.
  ///
  /// If [body] is `null` or empty, the body will be omitted.
  /// If individual items are `null`, they will be omitted,
  /// but separators will still be inserted.
  final List<Expression?>? body;

  /// Inserted between expressions in [body].
  ///
  /// If body contains multiple items, a non-`null` separator is required.
  /// An [ArgumentError] will be thrown if one is not provided.
  ///
  /// A space (" ") will be appended to the separator if it is followed
  /// by an expression. If an item in [body] is `null` (resulting in a
  /// blank string), no space will be inserted before it.
  final String? separator;

  /// Whether or not the body should be wrapped in parenthesis (default: `true`)
  final bool parenthesised;

  @visibleForTesting
  const ControlExpression(
    this.control, {
    this.body,
    this.separator,
    this.parenthesised = true,
  });

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlExpression(this, context);

  factory ControlExpression.ifStatement(Expression condition) =>
      ControlExpression('if', body: [condition]);

  factory ControlExpression.elseStatement(Expression? condition) =>
      ControlExpression(
        'else',
        body: condition != null ? [condition] : null,
        parenthesised: false,
      );

  factory ControlExpression.forLoop(
    Expression? initialize,
    Expression? condition,
    Expression? advance,
  ) => ControlExpression(
    'for',
    body: [initialize, condition, advance],
    separator: ';',
  );

  factory ControlExpression.forInLoop(
    Expression identifier,
    Expression expression,
  ) => ControlExpression(
    'for',
    body: [identifier, expression],
    separator: ' in',
  );

  factory ControlExpression.awaitForLoop(
    Expression identifier,
    Expression expression,
  ) => ControlExpression(
    'await for',
    body: [identifier, expression],
    separator: ' in',
  );

  factory ControlExpression.whileLoop(Expression condition) =>
      ControlExpression('while', body: [condition]);

  static const doStatement = ControlExpression('do');

  static const tryStatement = ControlExpression('try');

  factory ControlExpression.catchStatement(
    String error, [
    String? stacktrace,
  ]) => ControlExpression(
    'catch',
    body: [refer(error), if (stacktrace != null) refer(stacktrace)],
    separator: ',',
  );

  factory ControlExpression.onStatement(
    Reference type, [
    ControlExpression? statement,
  ]) => ControlExpression(
    'on',
    body: [type, if (statement != null) statement],
    parenthesised: false,
    separator: '',
  );

  static const finallyStatement = ControlExpression('finally');

  factory ControlExpression.switchStatement(Expression value) =>
      ControlExpression('switch', body: [value]);
}

/// **INTERNAL**
///
/// A collection control-flow expression
///
/// Supports chaining when used in collections via [chainTarget] and [chain].
/// These fields have no effect when used outside of collections.
///
@internal
class CollectionExpression extends BinaryExpression {
  /// Whether the [CollectionExpression] that follows this in a collection
  /// may chain with it. Chained expressions will not have a comma between
  /// them.
  final bool chainTarget;

  /// Whether this [CollectionExpression] should try to chain with its
  /// antecedent in collections.
  final bool chain;

  const CollectionExpression._({
    required Expression control,
    required Expression value,
    this.chain = false,
    this.chainTarget = false,
  }) : super._(control, value, '');
}

/// Provides control-flow utilities for [Expression].
///
/// {@category controlFlow}
extension ControlFlow on Expression {
  /// Returns `yield {this}`
  Expression get yielded =>
      BinaryExpression._(Expression._empty, this, 'yield');

  /// Returns `yield* {this}`
  Expression get yieldStarred =>
      BinaryExpression._(Expression._empty, this, 'yield*');

  /// Build a `while` loop from this expression.
  ///
  /// ```dart
  /// while (this) {
  ///   body
  /// }
  /// ```
  WhileLoop loopWhile(void Function(BlockBuilder block) builder) => WhileLoop(
    (loop) =>
        loop
          ..condition = this
          ..body.update(builder),
  );

  /// Build a `do-while` loop from this expression.
  ///
  /// ```dart
  /// do {
  ///   body
  /// } while (this);
  /// ```
  WhileLoop loopDoWhile(void Function(BlockBuilder block) builder) => WhileLoop(
    (loop) =>
        loop
          ..doWhile = true
          ..condition = this
          ..body.update(builder),
  );

  /// Build a `for-in` loop from this expression in [object].
  ///
  /// ```dart
  /// for (this in object) {
  ///   body
  /// }
  /// ```
  ForInLoop loopForIn(
    Expression object,
    void Function(BlockBuilder block) builder,
  ) => ForInLoop(
    (loop) =>
        loop
          ..object = object
          ..variable = this
          ..body.update(builder),
  );

  /// Build this expression into a [Conditional]
  ///
  /// ```dart
  /// if (this) {
  ///   body
  /// }
  /// ```
  ///
  /// Chain [Conditional.elseIf] and [Conditional.orElse] to
  /// easily create a full `if-elseif-else` tree:
  ///
  /// ```dart
  /// literal(1)
  ///     .equalTo(literal(2))
  ///     .ifThen(
  ///         (body) => body.addExpression(
  ///           refer('print').call([literal('Bad')]))
  ///     ).elseIf(
  ///       (block) => block
  ///         ..condition = literal(2).equalTo(literal(2))
  ///         ..body.addExpression(refer('print').call([literal('Good')])),
  ///     ).orElse(
  ///       (body) => body.addExpression(
  ///         refer('print').call([literal('What?')])),
  ///     );
  /// ```
  ///
  /// Outputs:
  /// ```dart
  /// if (1 == 2) {
  ///   print('Bad');
  /// } else if (2 == 2) {
  ///   print('Good');
  /// } else {
  ///   print('What?');
  /// }
  /// ```
  Conditional ifThen(void Function(BlockBuilder body) builder) => Conditional(
    (tree) =>
        tree..add(
          (branch) =>
              branch
                ..condition = this
                ..body.update(builder),
        ),
  );

  /// Returns `if (this) return value`
  Expression ifThenReturn([Expression? value]) => BinaryExpression._(
    ControlExpression.ifStatement(this),
    value == null ? ControlFlow.returnVoid : value.returned,
    '',
  );

  /// `return`
  static const returnVoid = LiteralExpression._('return');

  /// `break`
  ///
  /// For usage with a label, use [breakLabel].
  static const breakVoid = LiteralExpression._('break');

  /// `continue`
  ///
  /// For usage with a label, use [continueLabel].
  static const continueVoid = LiteralExpression._('continue');

  /// `rethrow`
  static const rethrowVoid = LiteralExpression._('rethrow');

  /// Returns a labeled `break` statement.
  ///
  /// ```dart
  /// break label
  /// ```
  ///
  /// For usage without a label, use [breakVoid].
  static Expression breakLabel(String label) =>
      BinaryExpression._(breakVoid, refer(label), '');

  /// Returns a labeled `continue` statement.
  ///
  /// ```dart
  /// continue label
  /// ```
  ///
  /// For usage without a label, use [continueVoid].
  static Expression continueLabel(String label) =>
      BinaryExpression._(continueVoid, refer(label), '');

  /// Returns a case match expression for an `if-case` statement,
  /// matching [object] against [pattern] with optional guard clause [guard].
  ///
  /// ```dart
  /// object case pattern
  /// object case pattern when guard
  /// ```
  ///
  /// See https://dart.dev/language/branches#if-case
  static Expression ifCase({
    required Expression object,
    required Expression pattern,
    Expression? guard,
  }) {
    final first = BinaryExpression._(object, pattern, 'case');
    if (guard == null) return first;
    return BinaryExpression._(first, guard, 'when');
  }

  /// Returns a collection-`if` expression.
  ///
  /// ```dart
  /// if (condition) value
  /// ```
  ///
  /// {@template controlflow.collection.chaining.if}
  /// [collectionIf] expressions followed by [collectionElse] expressions
  /// in a [literal] list, set, or map will be chained together, e.g:
  ///
  /// ```dart
  /// literalMap({
  ///   ControlFlow.collectionIf(
  ///       condition: literalTrue, value: refer('key')
  ///   ): refer('value'),
  ///   ControlFlow.collectionElse(
  ///       condition: literalFalse,
  ///       value: refer('key2')
  ///   ): refer('value2'),
  ///   ControlFlow.collectionElse(value: refer('key3')
  ///   ): refer('value3'),
  /// });
  /// ```
  /// Outputs:
  /// ```dart
  /// {
  ///   if (true) key: value
  ///   else if (false) key2: value2
  ///   else key3: value3
  /// }
  /// ```
  /// {@endtemplate}
  static Expression collectionIf({
    required Expression condition,
    required Expression value,
  }) => CollectionExpression._(
    chainTarget: true,
    control: ControlExpression.ifStatement(condition),
    value: value,
  );

  /// Returns a collection-`else` expression.
  ///
  /// If [condition] is specified, returns a collection-`else if` expression.
  ///
  /// ```dart
  /// else value
  /// else if (condition) value
  /// ```
  ///
  /// {@macro controlflow.collection.chaining.if}
  static Expression collectionElse({
    Expression? condition,
    required Expression value,
  }) => CollectionExpression._(
    chain: true,
    chainTarget: condition != null,
    // only chainable if this is an else-if statement
    control: ControlExpression.elseStatement(
      condition == null ? null : ControlExpression.ifStatement(condition),
    ),
    value: value,
  );

  /// Returns a collection-`for` expression.
  ///
  /// ```dart
  /// for (initialize; condition; advance) value
  /// ```
  ///
  /// {@template controlflow.collection.chaining.for}
  /// If [value] is chainable (a [collectionIf], [collectionElse] with a
  /// condition, or a collection-`for`/`for-in` containing one of those),
  /// this will also be chainable. If this is followed by a collection-`else`
  /// in a [literal] collection, they will be chained together.
  ///
  /// ```dart
  /// literalMap({
  ///   ControlFlow.collectionForIn(
  ///       identifier: declareFinal('x'),
  ///       expression: refer('items'),
  ///       value: ControlFlow.collectionIf(
  ///           condition: refer('x').property('valid'),
  ///           value: refer('key')
  ///   )): refer('x'),
  ///   ControlFlow.collectionElse(value: refer('key2')
  ///   ): refer('fix').call([refer('x')])
  /// });
  /// ```
  /// Outputs:
  /// ```dart
  /// {
  ///   for (final x in items) if (x.valid) key: x
  ///   else key2: fix
  /// }
  /// ```
  /// {@endtemplate}
  static Expression collectionFor({
    Expression? initialize,
    Expression? condition,
    Expression? advance,
    required Expression value,
  }) => CollectionExpression._(
    chainTarget: true,
    control: ControlExpression.forLoop(initialize, condition, advance),
    value: value,
  );

  /// Returns a collection-`for-in` expression
  ///
  /// ```dart
  /// for (identifier in expression) value
  /// ```
  ///
  /// {@macro controlflow.collection.chaining.for}
  static Expression collectionForIn({
    required Expression identifier,
    required Expression expression,
    required Expression value,
  }) => CollectionExpression._(
    chainTarget: value is CollectionExpression && value.chainTarget,
    control: ControlExpression.forInLoop(identifier, expression),
    value: value,
  );
}
