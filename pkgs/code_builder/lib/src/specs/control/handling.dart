// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../control.dart';

/// Represents a `catch` block.
///
/// See [Try]
///
/// {@category controlFlow}
abstract class Catch with ControlBody implements Built<Catch, CatchBuilder> {
  Catch._();

  /// Build a catch block.
  factory Catch([void Function(CatchBuilder builder) updates]) = _$Catch;

  /// Build a catch block from [body].
  ///
  /// Optionally, specify the exception and stacktrace variable names
  /// using [exception] and [stacktrace]. Use [type] to specify an `on`
  /// clause type.
  factory Catch.from(
    Code? body, {
    Reference? type,
    String? exception,
    String? stacktrace,
  }) => Catch(
    (builder) =>
        builder
          ..body = body
          ..type = type
          ..exception = exception
          ..stacktrace = stacktrace,
  );

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
abstract class Try
    with ControlBody
    implements Built<Try, TryBuilder>, Code, Spec {
  Try._() {
    if (handlers.isEmpty) {
      throw ArgumentError(
        'One or more `catch` clauses must be specified.',
        'handlers',
      );
    }
  }

  /// Build a [Try].
  factory Try([void Function(TryBuilder builder) updates]) = _$Try;

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
  BuiltList<Catch> get handlers;

  /// The optional `finally` clause body.
  ///
  /// ```dart
  /// finally {
  ///   handleAll
  /// }
  /// ```
  Code? get handleAll;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitTry(this, context);
}

/// Builds a [Try] block.
///
/// {@category controlFlow}
abstract class TryBuilder
    with ControlBodyBuilder
    implements Builder<Try, TryBuilder> {
  TryBuilder._();
  factory TryBuilder() = _$TryBuilder;

  /// The body of the `try` clause.
  ///
  /// ```dart
  /// try {
  ///   body
  /// }
  /// ```
  @override
  // ignore: overridden_fields
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
  ListBuilder<Catch> handlers = ListBuilder();

  /// Build a `catch` clause and add it to [handlers].
  void addCatch(Catch block) => handlers.add(block);

  /// Build a `finally` clause and update [handleAll].
  void addFinally(Code? code) => handleAll = code;
}
