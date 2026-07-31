// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A `switch` case used in either a [SwitchStatement] or a [SwitchExpression].
///
/// The case type is determined by the generic parameter [T], which defines
/// the type of [body] required.
///
/// For `switch` *statements*, [T] should be [Code] (e.g. a [Block]).
/// Bodies may be multi-line, and may also be left `null` to use case
/// fall-through. Additionally, labels are supported via [label].
///
/// ```dart
/// case pattern:
/// case pattern when guard:
///   body;
///
/// label:
/// case pattern:
///   body;
///   body;
/// ```
///
/// For `switch` *expressions*, [T] must be a non-null [Expression].
/// Fall-though is not supported in `switch` expressions, nor are labels.
/// Attempting to use fall-through by leaving [body] `null` will throw an
/// [ArgumentError], and setting [label] will have no effect.
///
/// ```dart
/// pattern => body,
/// pattern when guard => body,
/// ```
///
/// {@category controlFlow}
abstract class Case<T extends Spec?> implements Built<Case<T>, CaseBuilder<T>> {
  Case._() {
    if (isDefault == true) return;

    if (pattern == null) {
      throw ArgumentError(
        '`pattern` must be set if `isDefault` is not `true`',
        'pattern',
      );
    }
  }

  /// Build a new [Case].
  factory Case([void Function(CaseBuilder<T> builder) updates]) = _$Case<T>;

  /// Create a catch-all case, either `default` or wildcard (`_`).
  ///
  /// For [SwitchStatement], the `default` keyword will be used. [label] will be
  /// respected, if provided. To force use of the wildcard expression
  /// instead, use [Case.new] with [Expression.wildcard] as the pattern.
  ///
  /// For [SwitchExpression], a wildcard case will be created, as `switch`
  /// expressions don't support `default`. [label] will be ignored.
  factory Case.any(T body, {String? label}) => Case<T>(
    (b) =>
        b
          ..isDefault = true
          ..label = label
          ..body = body,
  );

  /// Create a [Case] from [pattern] and [body].
  factory Case.from(Expression pattern, T body) => Case<T>(
    (builder) =>
        builder
          ..pattern = pattern
          ..body = body,
  );

  /// The pattern to match.
  ///
  /// Must not be `null`, unless [isDefault] is set to `true`.
  ///
  Expression? get pattern;

  /// The optional guard (`when`) clause.
  Expression? get guard;

  /// An optional label for this case.
  ///
  /// **NOTE:** Only `switch` *statements* ([SwitchStatement]) support labels.
  /// Setting [label] with `switch` *expressions* ([SwitchExpression]) has no
  /// effect; the label will be silently ignored.
  String? get label;

  /// Whether or not this case is the default case.
  ///
  /// Note that setting [isDefault] to `true` will cause the value of
  /// [pattern] to be ignored.
  ///
  /// For [SwitchStatement], the `default` keyword will be used. For
  /// [SwitchExpression], this is equivalent to setting [pattern] to
  /// [Expression.wildcard].
  ///
  /// See also: [Case.any]
  ///
  bool? get isDefault;

  /// The body of this case.
  ///
  /// May be left null when used in a [SwitchStatement] to use case
  /// fall-through.
  ///
  /// May **not** be left null in a [SwitchExpression], as they do not support
  /// fall-through. Will throw an [ArgumentError] if left unset.
  //* T must be nullable, otherwise built_value will perform a check that it was
  //* actually set, causing an error when left null to use fallthrough. Instead,
  //* it is up to the buildable case implementations (see below) to validate
  //* this value.
  T? get body;
}

/// **INTERNAL**
/// Base class for `switch` types.
@internal
@optionalTypeArgs
@BuiltValue(instantiable: false)
sealed class Switch<T extends Spec?> implements Code, Spec {
  /// The value being matched against.
  ///
  /// ```dart
  /// switch (value) {
  ///   ...
  /// }
  /// ```
  Expression get value;

  /// The cases in the `switch` body.
  BuiltList<Case<T>> get cases;
}

/// **INTERNAL**
/// Base class for `switch` builders
@internal
@optionalTypeArgs
sealed class SwitchBuilder<T extends Spec?> {
  /// The value being matched against.
  ///
  /// ```dart
  /// switch (value) {
  ///   ...
  /// }
  /// ```
  Expression? value;

  /// The cases in the `switch` body.
  ListBuilder<Case<T>> cases = ListBuilder();
}

/// Represents a `switch` statement.
///
/// `switch` *statements* are standalone `switch` blocks that
/// use the `case` keyword and execute the case body when matched. Unlike
/// `switch` *expressions*, they do not return any value. See
/// https://dart.dev/language/branches#switch-statements.
///
/// ```dart
/// switch (value) {
///   case value:
///   case otherValue:
///     body;
///
///   case value when guard:
///     body;
///     continue label;
///
///   label:
///   default:
///     body;
/// }
/// ```
/// [Case]s used in a [SwitchStatement] may leave their [Case.body] `null` in
/// order to use case fall-through. They can also specify labels ([Case.label])
/// and guard clauses ([Case.guard]).
///
abstract class SwitchStatement
    implements Switch<Code?>, Built<SwitchStatement, SwitchStatementBuilder> {
  SwitchStatement._();

  /// Build a [SwitchStatement].
  factory SwitchStatement([
    void Function(SwitchStatementBuilder statement) updates,
  ]) = _$SwitchStatement;

  /// Build a [SwitchStatement] from [value] and [cases].
  factory SwitchStatement.from(Expression value, Iterable<Case<Code?>> cases) =>
      SwitchStatement(
        (statement) =>
            statement
              ..cases.addAll(cases)
              ..value = value,
      );

  @override
  T accept<T>(covariant ControlBlockVisitor<T> visitor, [T? context]) =>
      visitor.visitSwitchStatement(this, context);
}

/// Represents a `switch` expression.
///
/// `switch` *expressions* are `switch` blocks that return the body of the
/// matched case and use the arrow (`=>`) syntax. Unlike `switch` statements,
/// they do not use the `case` keyword, and case bodies can only consist of
/// a single expression. See
/// https://dart.dev/language/branches#switch-expressions.
///
/// ```dart
/// final variable = switch (value) {
///   value => body,
///   value when guard => body,
///   _ => body,
/// };
/// ```
///
/// [Case]s used in a [SwitchExpression] must have a non-`null` body. They may
/// contain guard clauses ([Case.guard]) but not labels ([Case.label]). If a
/// label is specified, it will be ignored.
///
abstract class SwitchExpression extends Expression
    implements
        Switch<Expression>,
        Built<SwitchExpression, SwitchExpressionBuilder> {
  SwitchExpression._();

  /// Build a [SwitchExpression].
  factory SwitchExpression([
    void Function(SwitchExpressionBuilder expression) updates,
  ]) = _$SwitchExpression;

  /// Build a [SwitchExpression] from [value] and [cases].
  factory SwitchExpression.from(
    Expression value,
    Iterable<Case<Expression>> cases,
  ) => SwitchExpression(
    (expression) =>
        expression
          ..cases.addAll(cases)
          ..value = value,
  );

  @override
  T accept<T>(covariant ControlBlockVisitor<T> visitor, [T? context]) =>
      visitor.visitSwitchExpression(this, context);
}
