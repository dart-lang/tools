// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A `catch` or `on` clause in a [Try] statement.
///
/// ```dart
/// on FormatException catch (e, s) {
///   body
/// }
/// ```
abstract class Catch implements Built<Catch, CatchBuilder> {
  factory Catch([void Function(CatchBuilder) updates]) = _$Catch;

  Catch._();

  /// The type of exception to catch (`on` clause).
  Reference? get on;

  /// The exception variable name.
  String? get exception;

  /// The stack trace variable name.
  String? get stackTrace;

  /// The catch block body.
  Code? get body;
}

abstract class CatchBuilder implements Builder<Catch, CatchBuilder> {
  factory CatchBuilder() = _$CatchBuilder;
  CatchBuilder._();

  Reference? on;
  String? exception;
  String? stackTrace;
  Code? body;
}

/// A `try` statement with optional `catch` and `finally` blocks.
///
/// ```dart
/// try {
///   body
/// } on FormatException catch (e, s) {
///   catchBody
/// } finally {
///   finallyBody
/// }
/// ```
abstract class Try implements Built<Try, TryBuilder>, Code, Spec {
  factory Try([void Function(TryBuilder) updates]) = _$Try;

  Try._() {
    if (catches.isEmpty && finallyBlock == null) {
      throw ArgumentError(
        'A try statement must specify at least one catch clause or a finally '
        'block.',
      );
    }
  }

  /// The body of the `try` block.
  Code? get body;

  /// The `catch` clauses for this try block.
  BuiltList<Catch> get catches;

  /// The optional `finally` block.
  Code? get finallyBlock;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitTry(this, context);
}

abstract class TryBuilder implements Builder<Try, TryBuilder> {
  factory TryBuilder() = _$TryBuilder;
  TryBuilder._();

  Code? body;
  ListBuilder<Catch> catches = ListBuilder<Catch>();
  Code? finallyBlock;
}
