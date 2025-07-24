// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_value/built_value.dart';
import 'package:meta/meta.dart';

import 'code.dart';
import 'expression.dart';

part 'control.g.dart';

/// Root class for control-flow blocks.
///
/// Most control-flow subclasses should mix in [ControlBlock] to avoid
/// duplication of boilerplate logic in [accept].
///
/// {@category controlFlow}
@internal
abstract mixin class ControlBlock implements Code {
  /// The full control-flow expression that precedes this block.
  @internal
  ControlExpression get expression;

  /// The body of this block.
  ///
  /// *Note: will always be wrapped in `{`braces`}`*.
  Block get body;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlBlock(this, context);
}

/// Control block that supports setting a label.
@internal
mixin Labeled on ControlBlock {
  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  String? get label;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitLabeledBlock(this);
}

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
    with ControlBlock, Labeled
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
  ControlExpression get expression =>
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
    with ControlBlock, Labeled
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
  ControlExpression get expression => async == true
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
    with ControlBlock, Labeled
    implements Built<WhileLoop, WhileLoopBuilder> {
  WhileLoop._();
  factory WhileLoop(void Function(WhileLoopBuilder loop) builder) = _$WhileLoop;

  /// Whether or not this is a `do-while` loop.
  bool? get doWhile;

  /// The loop condition.
  Expression get condition;

  /// Always returns the `while` statement, regardless
  /// of the value of [doWhile].
  @internal
  ControlExpression get statement => ControlExpression.whileLoop(condition);

  @override
  ControlExpression get expression =>
      doWhile == true ? ControlExpression.doStatement : statement;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitWhileLoop(this, context);
}

abstract class ControlBlockVisitor<T>
    implements ExpressionVisitor<T>, CodeVisitor<T> {
  T visitControlBlock(ControlBlock block, [T? context]);
  T visitLabeledBlock(Labeled block, [T? context]);
  T visitWhileLoop(WhileLoop loop, [T? context]);
}

abstract mixin class ControlBlockEmitter
    implements ControlBlockVisitor<StringSink> {
  @override
  StringSink visitControlBlock(ControlBlock block, [StringSink? output]) {
    output ??= StringBuffer();
    block.expression.accept(this, output);
    output.write('{');
    block.body.accept(this, output);
    output.write('}');
    return output;
  }

  @override
  StringSink visitLabeledBlock(Labeled block, [StringSink? output]) {
    output ??= StringBuffer();
    if (block.label != null) {
      output.write('${block.label!}: ');
    }

    return visitControlBlock(block, output);
  }

  @override
  StringSink visitWhileLoop(WhileLoop loop, [StringSink? output]) {
    output ??= StringBuffer();
    visitLabeledBlock(loop, output);

    if (loop.doWhile != true) return output;

    output.write(' ');
    loop.statement.statement.accept(this, output);
    return output;
  }
}
