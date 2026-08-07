// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A `for` loop statement.
///
/// ```dart
/// for (var i = 0; i < 10; i++) {
///   body
/// }
/// ```
abstract class ForLoop implements Built<ForLoop, ForLoopBuilder>, Code, Spec {
  factory ForLoop([void Function(ForLoopBuilder) updates]) = _$ForLoop;

  ForLoop._();

  /// An optional label for the loop.
  String? get label;

  /// The initializer expression.
  Expression? get initialize;

  /// The loop condition.
  Expression? get condition;

  /// The step/advance expression.
  Expression? get advance;

  /// The loop body.
  Code? get body;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitForLoop(this, context);
}

abstract class ForLoopBuilder implements Builder<ForLoop, ForLoopBuilder> {
  factory ForLoopBuilder() = _$ForLoopBuilder;
  ForLoopBuilder._();

  String? label;
  Expression? initialize;
  Expression? condition;
  Expression? advance;
  Code? body;
}

/// A `for-in` loop statement.
///
/// ```dart
/// for (final x in items) {
///   body
/// }
/// ```
///
/// When [async] is `true`, emits an `await for` loop:
/// ```dart
/// await for (final x in stream) {
///   body
/// }
/// ```
abstract class ForInLoop
    implements Built<ForInLoop, ForInLoopBuilder>, Code, Spec {
  factory ForInLoop([void Function(ForInLoopBuilder) updates]) = _$ForInLoop;

  ForInLoop._();

  /// An optional label for the loop.
  String? get label;

  /// Whether this is an asynchronous (`await for`) loop.
  bool get async;

  /// The loop variable declaration or expression (before `in`).
  Expression get variable;

  /// The iterable or stream object (after `in`).
  Expression get object;

  /// The loop body.
  Code? get body;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitForInLoop(this, context);
}

abstract class ForInLoopBuilder
    implements Builder<ForInLoop, ForInLoopBuilder> {
  factory ForInLoopBuilder() = _$ForInLoopBuilder;
  ForInLoopBuilder._();

  String? label;
  bool async = false;
  Expression? variable;
  Expression? object;
  Code? body;
}

/// A `while` or `do-while` loop statement.
///
/// ```dart
/// while (condition) {
///   body
/// }
/// ```
///
/// When [doWhile] is `true`, emits a `do-while` loop:
/// ```dart
/// do {
///   body
/// } while (condition);
/// ```
abstract class WhileLoop
    implements Built<WhileLoop, WhileLoopBuilder>, Code, Spec {
  factory WhileLoop([void Function(WhileLoopBuilder) updates]) = _$WhileLoop;

  WhileLoop._();

  /// An optional label for the loop.
  String? get label;

  /// Whether this is a `do-while` loop.
  bool get doWhile;

  /// The loop condition.
  Expression get condition;

  /// The loop body.
  Code? get body;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitWhileLoop(this, context);
}

abstract class WhileLoopBuilder
    implements Builder<WhileLoop, WhileLoopBuilder> {
  factory WhileLoopBuilder() = _$WhileLoopBuilder;
  WhileLoopBuilder._();

  String? label;
  bool doWhile = false;
  Expression? condition;
  Code? body;
}
