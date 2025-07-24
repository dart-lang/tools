// Copyright (c) 20125, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// Represents a control expression, such as an `if` or `for`
/// statement.
///
/// The expression consists of the control statement ([control]),
/// followed by the expression body (if provided), which consists of
/// all expressions in [body] joined by [separator], optionally
/// enclosed in parenthesis ([parenthesised]).
///
/// {@category controlFlow}
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

  /// This expression's label.
  ///
  /// https://dart.dev/language/loops#labels
  final String? label;

  const ControlExpression._(this.control,
      {this.body, this.separator, this.parenthesised = true, this.label});

  @override
  R accept<R>(covariant ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitControlExpression(this, context);

  /// Returns an `if` statement.
  ///
  /// ```dart
  /// if (condition)
  /// ```
  ///
  /// https://dart.dev/language/branches#if
  ///

  factory ControlExpression.ifStatement(Expression condition) =>
      ControlExpression._('if', body: [condition]);

  /// An `else` statement
  ///
  /// ```dart
  /// else
  /// ```
  ///
  /// https://dart.dev/language/branches#if
  ///

  static const elseStatement = ControlExpression._('else');

  /// Returns an `else if` statement
  ///
  /// ```dart
  /// else if (condition)
  /// ```
  ///
  /// https://dart.dev/language/branches#if
  ///

  factory ControlExpression.elseIfStatement(Expression condition) =>
      ControlExpression._('else if', body: [condition]);

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
      ControlExpression._('for',
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
      ControlExpression._('for',
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
      ControlExpression._('await for',
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
      ControlExpression._('while', body: [condition]);

  /// A `do` statement.
  ///
  /// ```dart
  /// do
  /// ```
  ///
  /// https://dart.dev/language/loops#while-and-do-while
  ///

  static const doStatement = ControlExpression._('do');

  /// Returns a `break` statement.
  ///
  /// ```dart
  /// break label
  /// ```
  ///
  /// https://dart.dev/language/loops#break-and-continue
  ///

  factory ControlExpression.breakStatement([String? label]) =>
      ControlExpression._('break',
          body: [if (label != null) refer(label)], parenthesised: false);

  /// Returns a `continue` statement.
  ///
  /// ```dart
  /// continue label
  /// ```
  ///
  /// https://dart.dev/language/loops#break-and-continue
  ///

  factory ControlExpression.continueStatement([String? label]) =>
      ControlExpression._('continue',
          body: [if (label != null) refer(label)], parenthesised: false);

  /// A `try` statement.
  ///
  /// ```dart
  /// try
  /// ```
  ///
  /// https://dart.dev/language/error-handling#catch
  ///

  static const tryStatement = ControlExpression._('try');

  /// Returns a `catch` statement.
  ///
  /// ```dart
  /// catch (error)
  /// catch (error, stacktrace)
  /// ```
  ///
  /// https://dart.dev/language/error-handling#catch
  ///

  factory ControlExpression.catchStatement(Expression error,
          [Expression? stacktrace]) =>
      ControlExpression._('catch',
          body: [error, if (stacktrace != null) stacktrace], separator: ',');

  /// Returns an `on` statement.
  ///
  /// ```dart
  /// on error
  /// ```
  ///
  /// https://dart.dev/language/error-handling#catch
  ///

  factory ControlExpression.onStatement(Expression error) =>
      ControlExpression._('on', body: [error], parenthesised: false);

  /// A `finally` statement.
  ///
  /// ```dart
  /// finally
  /// ```
  ///
  /// https://dart.dev/language/error-handling#finally
  ///

  static const finallyStatement = ControlExpression._('finally');

  /// Returns `label: {this}`
  ///
  /// https://dart.dev/language/loops#labels
  ControlExpression labeled(String label) => ControlExpression._(control,
      body: body,
      label: label,
      parenthesised: parenthesised,
      separator: separator);
}
