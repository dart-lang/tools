// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a traditional `for` loop.
///
/// ```dart
/// for (initialize; condition; advance) {
///   body
/// }
/// ```
///
/// https://dart.dev/language/loops#for-loops
///
/// {@category controlFlow}
abstract class ForLoop
    with ControlBlock, LabeledControlBlock
    implements Built<ForLoop, ForLoopBuilder> {
  ForLoop._();

  /// The initializer expression.
  ///
  /// Leave `null` to omit.
  Expression? get initialize;

  /// The for loop condition.
  ///
  /// Leave `null` to omit.
  Expression? get condition;

  /// The advancer expression.
  ///
  /// Leave `null` to omit.
  Expression? get advance;

  @override
  ControlExpression get _expression =>
      ControlExpression.forLoop(initialize, condition, advance);

  factory ForLoop(void Function(ForLoopBuilder loop) builder) = _$ForLoop;
}

/// Represents a `for-in` loop.
///
/// ```dart
/// for (variable in object) {
///   body
/// }
/// ```
///
/// If [async] is `true`, the loop will be asynchronous (`await for`):
/// ```dart
/// await for (variable in object) {
///   body
/// }
/// ```
///
/// https://dart.dev/language/loops#for-loops
///
/// {@category controlFlow}
abstract class ForInLoop
    with ControlBlock, LabeledControlBlock
    implements Built<ForInLoop, ForInLoopBuilder> {
  ForInLoop._();
  factory ForInLoop(void Function(ForInLoopBuilder loop) builder) = _$ForInLoop;

  /// Whether or not this is an asynchronous (`await for`) loop.
  bool? get async;

  /// The iterated variable (before `in`).
  Expression get variable;

  /// The object being iterated on (after `in`).
  Expression get object;

  @override
  ControlExpression get _expression => async == true
      ? ControlExpression.awaitForLoop(variable, object)
      : ControlExpression.forInLoop(variable, object);
}

/// Represents a `while` loop.
///
/// ```dart
/// while (condition) {
///   body
/// }
/// ```
///
/// If [doWhile] is `true`, the loop will be in the `do-while` format:
/// ```dart
/// do {
///   body
/// } while (condition);
/// ```
///
/// https://dart.dev/language/loops#while-and-do-while
///
/// {@category controlFlow}
abstract class WhileLoop
    with ControlBlock, LabeledControlBlock
    implements Built<WhileLoop, WhileLoopBuilder> {
  WhileLoop._();
  factory WhileLoop(void Function(WhileLoopBuilder loop) builder) = _$WhileLoop;

  /// Whether or not this is a `do-while` loop.
  bool? get doWhile;

  /// The loop condition.
  Expression get condition;

  /// Always returns the `while` statement, regardless
  /// of the value of [doWhile].
  ControlExpression get _statement => ControlExpression.whileLoop(condition);

  @override
  ControlExpression get _expression =>
      doWhile == true ? ControlExpression.doStatement : _statement;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitWhileLoop(this, context);
}
