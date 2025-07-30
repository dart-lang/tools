// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a `catch` block.
///
/// {@category controlFlow}
abstract class CatchBlock
    with ControlBlock
    implements Built<CatchBlock, CatchBlockBuilder> {
  CatchBlock._();
  factory CatchBlock([void Function(CatchBlockBuilder) updates]) = _$CatchBlock;

  /// The optional type of exception to catch (`on` clause).
  ///
  /// When [type] is set, leave [exception] and [stacktrace]
  /// `null` to omit the `catch` statement.
  ///
  /// ``` dart
  /// on type
  /// on type catch (exception)
  /// on type catch (exception, stacktrace)
  /// ```
  Reference? get type;

  /// The optional name of the exception parameter.
  ///
  /// If a [type] is specified, leaving this and [stacktrace] null
  /// will omit the `catch` statement entirely.
  ///
  /// If left `null` otherwise, a wildcard (`_`) will be used
  /// as the exception name.
  ///
  /// ```dart
  /// catch (exception)
  /// catch (exception, stacktrace)
  /// ```
  String? get exception;

  /// The optional name of the stacktrace parameter.
  ///
  /// Will be excluded if left `null`.
  ///
  /// ```dart
  /// catch (exception)
  /// catch (exception, stacktrace)
  /// ```
  String? get stacktrace;

  ControlExpression get _catch =>
      ControlExpression.catchStatement(exception ?? '_', stacktrace);

  @override
  ControlExpression get _expression {
    if (type == null) return _catch;

    // omit catch clause if exception and stacktrace are unspecified
    if (exception == null && stacktrace == null) {
      return ControlExpression.onStatement(type!);
    }

    return ControlExpression.onStatement(type!, _catch);
  }
}

/// Represents a `try` or `finally` block.
///
/// **INTERNAL ONLY**.
@internal
class TryBlock with ControlBlock {
  @override
  final Block body;
  final bool isFinally;

  const TryBlock._(this.body) : isFinally = false;
  const TryBlock._finally(this.body) : isFinally = true;

  @override
  ControlExpression get _expression => isFinally
      ? ControlExpression.finallyStatement
      : ControlExpression.tryStatement;
}

/// Represents a `try`/`catch` block.
///
/// {@category controlFlow}
abstract class TryCatch
    with ControlTree
    implements Built<TryCatch, TryCatchBuilder> {
  TryCatch._();

  /// Build a [TryCatch].
  factory TryCatch([void Function(TryCatchBuilder) updates]) = _$TryCatch;

  /// The body of the `try` clause.
  ///
  /// ```dart
  /// try {
  ///   body
  /// }
  /// ```
  Block get body;

  /// The `catch` clauses for this block.
  BuiltList<CatchBlock> get handlers;

  /// The optional `finally` clause body.
  ///
  /// ```dart
  /// finally {
  ///   handleAll
  /// }
  /// ```
  Block? get handleAll;

  TryBlock get _try => TryBlock._(body);
  TryBlock? get _finally =>
      handleAll == null ? null : TryBlock._finally(handleAll!);

  @override
  List<ControlBlock?> get _blocks => [_try, ...handlers, _finally];

  /// Ensure [handlers] is not empty
  @BuiltValueHook(finalizeBuilder: true)
  static void _build(TryCatchBuilder builder) =>
      builder.handlers.isNotEmpty ||
      (throw ArgumentError(
          'One or more `catch` clauses must be specified.', 'handlers'));
}

/// Builds a [TryCatch] block.
///
/// {@category controlFlow}
abstract class TryCatchBuilder implements Builder<TryCatch, TryCatchBuilder> {
  TryCatchBuilder._();
  factory TryCatchBuilder() = _$TryCatchBuilder;

  /// The body of the `try` clause.
  ///
  /// ```dart
  /// try {
  ///   body
  /// }
  /// ```
  BlockBuilder body = BlockBuilder();

  /// The optional `finally` clause body.
  ///
  /// ```dart
  /// finally {
  ///   handleAll
  /// }
  /// ```
  BlockBuilder? handleAll;

  /// The `catch` clauses for this block.
  ListBuilder<CatchBlock> handlers = ListBuilder();

  /// Build a `catch` clause and add it to [handlers].
  void addCatch(void Function(CatchBlockBuilder block) builder) =>
      handlers.add((CatchBlockBuilder()..update(builder)).build());

  /// Build a `finally` clause and update [handleAll].
  void addFinally(void Function(BlockBuilder body) builder) =>
      handleAll = BlockBuilder()..update(builder);
}
