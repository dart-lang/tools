// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a `catch` block.
///
/// See [TryCatch]
///
/// {@category controlFlow}
abstract class CatchBlock
    with ControlBody
    implements Built<CatchBlock, CatchBlockBuilder> {
  CatchBlock._();
  factory CatchBlock([void Function(CatchBlockBuilder builder) updates]) =
      _$CatchBlock;

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
}

/// Represents a `try`/`catch` block.
///
/// {@category controlFlow}
abstract class TryCatch
    with ControlBody
    implements Built<TryCatch, TryCatchBuilder>, Code, Spec {
  TryCatch._();

  /// Build a [TryCatch].
  factory TryCatch([void Function(TryCatchBuilder builder) updates]) =
      _$TryCatch;

  /// The body of the `try` clause.
  ///
  /// ```dart
  /// try {
  ///   body
  /// }
  /// ```
  @override
  Code? get body;

  /// The `catch` clauses for this block.
  BuiltList<CatchBlock> get handlers;

  /// The optional `finally` clause body.
  ///
  /// ```dart
  /// finally {
  ///   handleAll
  /// }
  /// ```
  Code? get handleAll;

  /// Ensure [handlers] is not empty
  @BuiltValueHook(finalizeBuilder: true)
  static void _build(TryCatchBuilder builder) =>
      builder.handlers.isNotEmpty ||
      (throw ArgumentError(
        'One or more `catch` clauses must be specified.',
        'handlers',
      ));

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitTryCatch(this, context);
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
  Code? body;

  /// The optional `finally` clause body.
  ///
  /// ```dart
  /// finally {
  ///   handleAll
  /// }
  /// ```
  Code? handleAll;

  /// The `catch` clauses for this block.
  ListBuilder<CatchBlock> handlers = ListBuilder();

  /// Build a `catch` clause and add it to [handlers].
  void addCatch(CatchBlock block) => handlers.add(block);

  /// Build a `finally` clause and update [handleAll].
  void addFinally(Code? code) => handleAll = code;
}
