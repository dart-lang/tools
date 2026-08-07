// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../control.dart';

/// A case within a [SwitchStatement].
///
/// ```dart
/// case pattern when guard:
///   body;
/// ```
abstract class CaseStatement
    implements Built<CaseStatement, CaseStatementBuilder> {
  factory CaseStatement([void Function(CaseStatementBuilder) updates]) =
      _$CaseStatement;

  CaseStatement._() {
    if (isDefault != true && pattern == null) {
      throw ArgumentError(
        'A case statement must specify a pattern unless isDefault is true.',
      );
    }
  }

  /// An optional label for this case.
  String? get label;

  /// Whether this is the `default:` case.
  bool get isDefault;

  /// The pattern to match against.
  Pattern? get pattern;

  /// The optional guard (`when`) expression.
  Expression? get guard;

  /// The body of this case.
  ///
  /// May be `null` to represent case fall-through.
  Code? get body;
}

abstract class CaseStatementBuilder
    implements Builder<CaseStatement, CaseStatementBuilder> {
  factory CaseStatementBuilder() = _$CaseStatementBuilder;
  CaseStatementBuilder._();

  String? label;
  bool isDefault = false;
  Pattern? pattern;
  Expression? guard;
  Code? body;
}

/// A `switch` statement.
///
/// ```dart
/// switch (value) {
///   case 1:
///   case 2:
///     body;
///   default:
///     defaultBody;
/// }
/// ```
abstract class SwitchStatement
    implements Built<SwitchStatement, SwitchStatementBuilder>, Code, Spec {
  factory SwitchStatement([void Function(SwitchStatementBuilder) updates]) =
      _$SwitchStatement;

  SwitchStatement._();

  /// An optional label for the switch statement.
  String? get label;

  /// The value being matched against.
  Expression get value;

  /// The cases in the switch statement.
  BuiltList<CaseStatement> get cases;

  @override
  R accept<R>(covariant ControlVisitor<R> visitor, [R? context]) =>
      visitor.visitSwitchStatement(this, context);
}

abstract class SwitchStatementBuilder
    implements Builder<SwitchStatement, SwitchStatementBuilder> {
  factory SwitchStatementBuilder() = _$SwitchStatementBuilder;
  SwitchStatementBuilder._();

  String? label;
  Expression? value;
  ListBuilder<CaseStatement> cases = ListBuilder<CaseStatement>();
}

/// A case within a [SwitchExpression].
///
/// ```dart
/// pattern when guard => body,
/// ```
abstract class CaseExpression
    implements Built<CaseExpression, CaseExpressionBuilder> {
  factory CaseExpression([void Function(CaseExpressionBuilder) updates]) =
      _$CaseExpression;

  CaseExpression._();

  /// The pattern to match against.
  Pattern get pattern;

  /// The optional guard (`when`) expression.
  Expression? get guard;

  /// The expression to evaluate when matched.
  Expression get body;
}

abstract class CaseExpressionBuilder
    implements Builder<CaseExpression, CaseExpressionBuilder> {
  factory CaseExpressionBuilder() = _$CaseExpressionBuilder;
  CaseExpressionBuilder._();

  Pattern? pattern;
  Expression? guard;
  Expression? body;
}

/// A `switch` expression.
///
/// ```dart
/// final x = switch (value) {
///   1 => 'one',
///   _ => 'other',
/// };
/// ```
abstract class SwitchExpression extends Expression
    implements Built<SwitchExpression, SwitchExpressionBuilder> {
  factory SwitchExpression([void Function(SwitchExpressionBuilder) updates]) =
      _$SwitchExpression;

  SwitchExpression._();

  /// The value being matched against.
  Expression get value;

  /// The cases in the switch expression.
  BuiltList<CaseExpression> get cases;

  @override
  R accept<R>(covariant ExpressionVisitor<R> visitor, [R? context]) =>
      (visitor as ControlVisitor<R>).visitSwitchExpression(this, context);
}

abstract class SwitchExpressionBuilder
    implements Builder<SwitchExpression, SwitchExpressionBuilder> {
  factory SwitchExpressionBuilder() = _$SwitchExpressionBuilder;
  SwitchExpressionBuilder._();

  Expression? value;
  ListBuilder<CaseExpression> cases = ListBuilder<CaseExpression>();
}
