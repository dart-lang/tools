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
    with ControlBody, ControlLabel
    implements Built<ForLoop, ForLoopBuilder>, Code, Spec {
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

  factory ForLoop(void Function(ForLoopBuilder loop) builder) = _$ForLoop;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitForLoop(this, context);
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
    with ControlBody, ControlLabel
    implements Built<ForInLoop, ForInLoopBuilder>, Code, Spec {
  ForInLoop._();
  factory ForInLoop(void Function(ForInLoopBuilder loop) builder) = _$ForInLoop;

  /// Whether or not this is an asynchronous (`await for`) loop.
  bool? get async;

  /// The iterated variable (before `in`).
  Expression get variable;

  /// The object being iterated on (after `in`).
  Expression get object;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitForInLoop(this, context);
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
    with ControlBody, ControlLabel
    implements Built<WhileLoop, WhileLoopBuilder>, Code, Spec {
  WhileLoop._();
  factory WhileLoop(void Function(WhileLoopBuilder loop) builder) = _$WhileLoop;

  /// Whether or not this is a `do-while` loop.
  bool? get doWhile;

  /// The loop condition.
  Expression get condition;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitWhileLoop(this, context);
}
