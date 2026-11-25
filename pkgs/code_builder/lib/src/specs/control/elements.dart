// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// An `if` (and optional `else`) element inside a collection literal.
///
/// Braced [Conditional] statements cannot appear inside [literalList],
/// [literalSet], or [literalMapElements]; an [IfElement] can:
///
/// ```dart
/// literalList([
///   IfElement(Condition.expression(refer('ok')), literal(1), literal(2)),
/// ]);
/// // Emits: [if (ok) 1 else 2]
/// ```
///
/// The [condition] may be a boolean ([Condition.expression]) or a pattern
/// match ([Condition.ifCase]). Pass another [IfElement] as [orElse] to emit
/// `else if`.
class IfElement implements Spec {
  /// The condition deciding between [then] and [orElse].
  final Condition condition;

  /// The element included when [condition] matches.
  final Spec then;

  /// The element included when [condition] does not match, if any.
  final Spec? orElse;

  /// Creates an `if` element.
  ///
  /// Throws an [ArgumentError] if [orElse] is given and [then] ends in an `if`
  /// element that has no `else` (directly, at the tail of an `else if` chain,
  /// or as the body of a [ForElement]). Dart would bind the `else` to that
  /// inner `if` and silently change which branch runs.
  IfElement(this.condition, this.then, [this.orElse]) {
    if (orElse != null && _hasTrailingUnmatchedIf(then)) {
      throw ArgumentError.value(
        then,
        'then',
        'Cannot attach an else branch when the then element ends with an '
            'unmatched if element, because Dart binds else to the innermost '
            'if.',
      );
    }
  }

  static bool _hasTrailingUnmatchedIf(Spec element) => switch (element) {
    IfElement(:final orElse) =>
      orElse == null || _hasTrailingUnmatchedIf(orElse),
    ForElement(:final body) => _hasTrailingUnmatchedIf(body),
    _ => false,
  };

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitIfElement(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}

/// A `for` or `for-in` element inside a collection literal.
///
/// Braced [ForLoop] and [ForInLoop] statements cannot appear inside
/// [literalList], [literalSet], or [literalMapElements]; a [ForElement] can:
///
/// ```dart
/// literalList([
///   ForElement.forIn(declareFinal('x'), refer('items'), refer('x')),
/// ]);
/// // Emits: [for (final x in items) x]
/// ```
abstract class ForElement implements Spec {
  const ForElement._();

  /// Creates a `for (initialize; condition; advance) body` element.
  ///
  /// ```dart
  /// ForElement(
  ///   initialize: declareVar('i').assign(literal(0)),
  ///   condition: refer('i').lessThan(literal(3)),
  ///   advance: refer('i').operatorUnaryPostfixIncrement(),
  ///   body: refer('i'),
  /// );
  /// // Emits: for (var i = 0; i < 3; i++) i
  /// ```
  const factory ForElement({
    Expression? initialize,
    Expression? condition,
    Expression? advance,
    required Spec body,
  }) = ForLoopElement._;

  /// Creates a `for (variable in object) body` element, or an `await for`
  /// element when [async] is `true`.
  const factory ForElement.forIn(
    Expression variable,
    Expression object,
    Spec body, {
    bool async,
  }) = ForInElement._;

  /// The element produced on each iteration.
  Spec get body;
}

/// A `for (initialize; condition; advance) body` collection element.
///
/// Create one with [ForElement.new].
class ForLoopElement extends ForElement {
  /// The initializer, evaluated once before the loop.
  final Expression? initialize;

  /// The condition, evaluated before each iteration.
  final Expression? condition;

  /// The step expression, evaluated after each iteration.
  final Expression? advance;

  @override
  final Spec body;

  const ForLoopElement._({
    this.initialize,
    this.condition,
    this.advance,
    required this.body,
  }) : super._();

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitForLoopElement(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}

/// A `for (variable in object) body` collection element.
///
/// Create one with [ForElement.forIn].
class ForInElement extends ForElement {
  /// The loop variable declaration or identifier before `in`.
  final Expression variable;

  /// The [Iterable], or the [Stream] when [async], being iterated.
  final Expression object;

  /// Whether this is an `await for` element.
  final bool async;

  @override
  final Spec body;

  const ForInElement._(
    this.variable,
    this.object,
    this.body, {
    this.async = false,
  }) : super._();

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitForInElement(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}
