// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// Represents a control expression.
///
/// The expression consists of the control statement ([control]),
/// followed by the expression body (if provided), which consists of
/// all expressions in [body] joined by [separator], optionally
/// enclosed in parenthesis ([parenthesised]).
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
  ///
  /// If [body] is `null` or empty, [parenthesised] will have no effect.
  final bool parenthesised;

  @visibleForTesting
  const ControlExpression(this.control,
      {this.body, this.separator, this.parenthesised = true});

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlExpression(this, context);

  factory ControlExpression.ifStatement(Expression condition) =>
      ControlExpression('if', body: [condition]);

  factory ControlExpression.elseStatement(Expression? condition) =>
      ControlExpression('else',
          body: condition != null ? [condition] : null, parenthesised: false);

  /// Returns a traditional `for` loop.
  ///
  /// ```dart
  /// for (initialize; condition; advance)
  /// ```
  ///
  /// https://dart.dev/language/loops#for-loops
  ///

  factory ControlExpression.forLoop(
          Expression? initialize, Expression? condition, Expression? advance) =>
      ControlExpression('for',
          body: [initialize, condition, advance], separator: ';');

  /// Returns a `for-in` loop.
  ///
  /// ```dart
  /// for (identifier in expression)
  /// ```
  ///
  /// https://dart.dev/language/loops#for-loops
  ///

  factory ControlExpression.forInLoop(
          Expression identifier, Expression expression) =>
      ControlExpression('for',
          body: [identifier, expression], separator: ' in');

  /// Returns an asynchronous `for` loop.
  ///
  /// ```dart
  /// await for (identifier in expression)
  /// ```
  ///
  /// https://dart.dev/language/async#handling-streams
  ///

  factory ControlExpression.awaitForLoop(
          Expression identifier, Expression expression) =>
      ControlExpression('await for',
          body: [identifier, expression], separator: ' in');

  /// Returns a `while` loop.
  ///
  /// ```dart
  /// while (condition)
  /// ```
  ///
  /// https://dart.dev/language/loops#while-and-do-while
  ///

  factory ControlExpression.whileLoop(Expression condition) =>
      ControlExpression('while', body: [condition]);

  /// A `do` statement.
  ///
  /// ```dart
  /// do
  /// ```
  ///
  /// https://dart.dev/language/loops#while-and-do-while
  ///

  static const doStatement = ControlExpression('do');

  static const tryStatement = ControlExpression('try');

  factory ControlExpression.catchStatement(String error,
          [String? stacktrace]) =>
      ControlExpression('catch',
          body: [refer(error), if (stacktrace != null) refer(stacktrace)],
          separator: ',');

  factory ControlExpression.onStatement(
          Reference type, ControlExpression statement) =>
      ControlExpression('on',
          body: [type, statement], parenthesised: false, separator: '');

  /// A `finally` statement.
  ///
  /// ```dart
  /// finally
  /// ```
  ///
  /// https://dart.dev/language/error-handling#finally
  ///

  static const finallyStatement = ControlExpression('finally');
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
  WhileLoop loopWhile(void Function(BlockBuilder block) builder) =>
      WhileLoop((loop) => loop
        ..condition = this
        ..body.update(builder));

  /// Build a `do-while` loop from this expression.
  ///
  /// ```dart
  /// do {
  ///   body
  /// } while (this);
  /// ```
  WhileLoop loopDoWhile(void Function(BlockBuilder block) builder) =>
      WhileLoop((loop) => loop
        ..doWhile = true
        ..condition = this
        ..body.update(builder));

  /// Build a `for-in` loop from this expression in [object].
  ///
  /// ```dart
  /// for (this in object) {
  ///   body
  /// }
  /// ```
  ForInLoop loopForIn(
          Expression object, void Function(BlockBuilder block) builder) =>
      ForInLoop((loop) => loop
        ..object = object
        ..variable = this
        ..body.update(builder));

  /// Build this expression into an `if` [Condition] and add it
  /// to a new [IfTree].
  ///
  /// ```dart
  /// if (this) {
  ///   body
  /// }
  /// ```
  ///
  /// Chain [IfTree.elseIf] and [IfTree.orElse] to easily create a full
  /// `if-elseif-else` tree:
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
  IfTree ifThen(void Function(BlockBuilder body) builder) => Condition(
        (block) => block
          ..condition = this
          ..body.update(builder),
      ).asTree;

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
  static Expression ifCase(
      {required Expression object,
      required Expression pattern,
      Expression? guard}) {
    final first = BinaryExpression._(object, pattern, 'case');
    if (guard == null) return first;
    return BinaryExpression._(first, guard, 'when');
  }
}
