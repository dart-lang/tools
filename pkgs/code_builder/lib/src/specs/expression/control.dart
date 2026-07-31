// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// Represents a control-flow expression.
///
/// {@category controlFlow}
abstract class ControlExpression extends Expression {
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

  const ControlExpression(
    this.control, {
    this.body,
    this.separator,
    this.parenthesised = true,
  });

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlExpression(this, context);
}

/// Base [ControlExpression] implementation.
///
/// ** INTERNAL**
class BaseControlExpression extends ControlExpression {
  BaseControlExpression.ifStatement(Expression condition)
    : super('if', body: [condition]);

  BaseControlExpression.elseStatement(Expression? condition)
    : super(
        'else',
        body: condition != null ? [condition] : null,
        parenthesised: false,
      );

  BaseControlExpression.forLoop(
    Expression? initialize,
    Expression? condition,
    Expression? advance,
  ) : super('for', body: [initialize, condition, advance], separator: ';');

  BaseControlExpression.forInLoop(Expression identifier, Expression expression)
    : super('for', body: [identifier, expression], separator: ' in');

  BaseControlExpression.awaitForLoop(
    Expression identifier,
    Expression expression,
  ) : super('await for', body: [identifier, expression], separator: ' in');

  BaseControlExpression.whileLoop(Expression condition)
    : super('while', body: [condition]);

  BaseControlExpression.catchStatement(String error, [String? stacktrace])
    : super(
        'catch',
        body: [refer(error), if (stacktrace != null) refer(stacktrace)],
        separator: ',',
      );

  BaseControlExpression.onStatement(
    Reference type, [
    BaseControlExpression? statement,
  ]) : super(
         'on',
         body: [type, if (statement != null) statement],
         parenthesised: false,
         separator: '',
       );

  BaseControlExpression.switchStatement(Expression value)
    : super('switch', body: [value]);

  @visibleForTesting
  const BaseControlExpression(
    super.control, {
    super.body,
    super.parenthesised,
    super.separator,
  });

  static const doStatement = BaseControlExpression('do');
  static const tryStatement = BaseControlExpression('try');
  static const finallyStatement = BaseControlExpression('finally');
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
