// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A conditional `if` (and optional `else` or `else if`) collection element.
///
/// Use [IfElement] to conditionally include elements inside collection literals
/// such as [literalList] or [literalSet], where braced [Conditional] statements
/// cannot appear:
///
/// ```dart
/// literalList([
///   literal(1),
///   IfElement(Condition.expression(refer('includeTwo')), literal(2)),
/// ]);
/// // Emits: [1, if (includeTwo) 2]
/// ```
class IfElement implements Spec {
  /// The [Condition] evaluated to decide whether to include [then] or [orElse].
  ///
  /// Supports both boolean conditions via [Condition.expression] and
  /// pattern-matching conditions via [Condition.ifCase]:
  ///
  /// ```dart
  /// IfElement(
  ///   Condition.ifCase(refer('input'), Pattern.declareFinal('value')),
  ///   refer('value'),
  /// )
  /// ```
  final Condition condition;

  /// The collection element included when [condition] matches.
  ///
  /// May be an [Expression], a nested [IfElement], a [ForElement], or any other
  /// collection element [Spec]:
  ///
  /// ```dart
  /// IfElement(Condition.expression(refer('enabled')), refer('item'))
  /// ```
  final Spec then;

  /// The optional collection element included when [condition] does not match.
  ///
  /// Pass another [IfElement] to emit an `else if` chain:
  ///
  /// ```dart
  /// IfElement(
  ///   Condition.expression(refer('isPrimary')),
  ///   literal('primary'),
  ///   IfElement(
  ///     Condition.expression(refer('isSecondary')),
  ///     literal('secondary'),
  ///     literal('fallback'),
  ///   ),
  /// )
  /// // Emits: if (isPrimary) 'primary' else if (isSecondary) 'secondary' else 'fallback'
  /// ```
  final Spec? orElse;

  /// Creates a conditional `if` collection element with an optional [orElse]
  /// branch.
  ///
  /// Throws an [ArgumentError] if [orElse] is non-null and [then] ends with an
  /// unmatched [IfElement] (directly, at the tail of an `else if` chain, or as
  /// the body of a [ForElement]), because Dart binds `else` to the innermost
  /// `if` rather than the outer [IfElement]:
  ///
  /// ```dart
  /// literalSet([
  ///   IfElement(
  ///     Condition.expression(refer('useDefault')),
  ///     literal('default'),
  ///     literal('custom'),
  ///   ),
  /// ]);
  /// // Emits: {if (useDefault) 'default' else 'custom'}
  /// ```
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

/// An iterative `for` or `for-in` collection element.
///
/// Use [ForElement] to generate collection elements inside collection literals
/// such as [literalList] or [literalSet], where braced [ForLoop] and
/// [ForInLoop] statements cannot appear:
///
/// ```dart
/// literalList([
///   ForElement.forIn(declareFinal('x'), refer('items'), refer('x')),
/// ]);
/// // Emits: [for (final x in items) x]
/// ```
abstract class ForElement implements Spec {
  const ForElement._();

  /// Creates a C-style `for (initialize; condition; advance) body` collection
  /// element, backed by [ForLoopElement].
  ///
  /// Use this constructor when index-based or custom step iteration is needed
  /// inside a collection literal:
  ///
  /// ```dart
  /// literalList([
  ///   ForElement(
  ///     refer('i'),
  ///     initialize: declareVar('i').assign(literal(0)),
  ///     condition: refer('i').lessThan(literal(3)),
  ///     advance: refer('i').operatorUnaryPostfixIncrement(),
  ///   ),
  /// ]);
  /// // Emits: [for (var i = 0; i < 3; i++) i]
  /// ```
  const factory ForElement(
    Spec body, {
    Expression? initialize,
    Expression? condition,
    Expression? advance,
  }) = ForLoopElement._;

  /// Creates a `for (variable in object) body` (or `await for` when [async] is
  /// `true`) collection element, backed by [ForInElement].
  ///
  /// Use this constructor to project elements from an [Iterable] or [Stream]
  /// into a collection literal:
  ///
  /// ```dart
  /// literalSet([
  ///   ForElement.forIn(
  ///     declareFinal('event'),
  ///     refer('stream'),
  ///     refer('event'),
  ///     async: true,
  ///   ),
  /// ]);
  /// // Emits: {await for (final event in stream) event}
  /// ```
  const factory ForElement.forIn(
    Expression variable,
    Expression object,
    Spec body, {
    bool async,
  }) = ForInElement._;

  /// The collection element evaluated on each iteration of this loop.
  ///
  /// May be an [Expression], an [IfElement], a nested [ForElement], or any
  /// other collection element [Spec]:
  ///
  /// ```dart
  /// ForElement.forIn(declareFinal('x'), refer('xs'), refer('x'))
  /// ```
  Spec get body;
}

/// A C-style `for (initialize; condition; advance) body` collection element.
///
/// Construct instances using [ForElement.new] when generating collection
/// elements from an index or custom step expression:
///
/// ```dart
/// ForElement(
///   refer('i'),
///   initialize: declareVar('i').assign(literal(0)),
///   condition: refer('i').lessThan(literal(5)),
///   advance: refer('i').operatorUnaryPostfixIncrement(),
/// )
/// ```
class ForLoopElement extends ForElement {
  /// The optional initializer expression evaluated once before the loop runs.
  ///
  /// ```dart
  /// ForElement(refer('i'), initialize: declareVar('i').assign(literal(0)))
  /// ```
  final Expression? initialize;

  /// The optional condition expression evaluated before each iteration.
  ///
  /// ```dart
  /// ForElement(refer('x'), condition: refer('hasMore'))
  /// ```
  final Expression? condition;

  /// The optional step expression evaluated after each iteration.
  ///
  /// ```dart
  /// ForElement(
  ///   refer('i'),
  ///   advance: refer('i').operatorUnaryPostfixIncrement(),
  /// )
  /// ```
  final Expression? advance;

  /// The collection element evaluated on each iteration of the loop.
  ///
  /// ```dart
  /// ForElement(refer('item'))
  /// ```
  @override
  final Spec body;

  const ForLoopElement._(
    this.body, {
    this.initialize,
    this.condition,
    this.advance,
  }) : super._();

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitForLoopElement(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}

/// A `for-in` or `await for-in` collection element.
///
/// Construct instances using [ForElement.forIn] when projecting elements of an
/// [Iterable] or [Stream] into a collection literal:
///
/// ```dart
/// ForElement.forIn(declareFinal('item'), refer('items'), refer('item'))
/// ```
class ForInElement extends ForElement {
  /// The loop variable declaration or identifier before `in`.
  ///
  /// ```dart
  /// ForElement.forIn(declareFinal('item'), refer('items'), refer('item'))
  /// ```
  final Expression variable;

  /// The [Iterable] or [Stream] expression after `in` being iterated.
  ///
  /// ```dart
  /// ForElement.forIn(declareVar('x'), refer('values'), refer('x'))
  /// ```
  final Expression object;

  /// Whether this element awaits a [Stream] using `await for` rather than
  /// synchronous `for`.
  ///
  /// ```dart
  /// ForElement.forIn(
  ///   declareFinal('chunk'),
  ///   refer('chunks'),
  ///   refer('chunk'),
  ///   async: true,
  /// )
  /// ```
  final bool async;

  /// The collection element evaluated for each element of [object].
  ///
  /// ```dart
  /// ForElement.forIn(declareFinal('x'), refer('xs'), refer('x'))
  /// ```
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
