// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../expression.dart';

/// Converts a runtime Dart [literal] value into an [Expression].
///
/// Supported Dart types are translated into literal expressions.
/// If the [literal] is already an [Expression] it is returned without change to
/// allow operating on a collection of mixed simple literals and more complex
/// expressions.
/// Unsupported inputs invoke the [onError] callback.
Expression literal(Object? literal, {Expression Function(Object)? onError}) {
  if (literal is Expression) return literal;
  if (literal is bool) return literalBool(literal);
  if (literal is num) return literalNum(literal);
  if (literal is String) return literalString(literal);
  if (literal is List) return literalList(literal);
  if (literal is Set) return literalSet(literal);
  if (literal is Map) return literalMap(literal);
  if (literal == null) return literalNull;
  if (onError != null) return onError(literal);
  throw UnsupportedError('Not a supported literal type: $literal.');
}

/// Represents the literal value `true`.
const Expression literalTrue = LiteralExpression._('true');

/// Represents the literal value `false`.
const Expression literalFalse = LiteralExpression._('false');

/// Create a literal expression from a boolean [value].
Expression literalBool(bool value) => value ? literalTrue : literalFalse;

/// Represents the literal value `null`.
const Expression literalNull = LiteralExpression._('null');

/// Create a literal expression from a number [value].
Expression literalNum(num value) => LiteralExpression._('$value');

/// Create a literal expression from a string [value].
///
/// **NOTE**: The string is always formatted `'<value>'`.
///
/// If [raw] is `true`, creates a raw String formatted `r'<value>'` and the
/// value may not contain a single quote.
/// Escapes single quotes and newlines in the value.
Expression literalString(String value, {bool raw = false}) {
  if (raw && value.contains('\'')) {
    throw ArgumentError('Cannot include a single quote in a raw string');
  }
  final escaped = value.replaceAll('\'', '\\\'').replaceAll('\n', '\\n');
  return LiteralExpression._("${raw ? 'r' : ''}'$escaped'");
}

/// Create a literal `...` operator for use when creating a Map literal.
///
/// *NOTE* This is used as a sentinel when constructing a `literalMap` or a
/// or `literalConstMap` to signify that the value should be spread. Do NOT
/// reuse the value when creating a Map with multiple spreads.
Expression literalSpread() => LiteralSpreadExpression._(false);

/// Create a literal `...?` operator for use when creating a Map literal.
///
/// *NOTE* This is used as a sentinel when constructing a `literalMap` or a
/// or `literalConstMap` to signify that the value should be spread. Do NOT
/// reuse the value when creating a Map with multiple spreads.
Expression literalNullSafeSpread() => LiteralSpreadExpression._(true);

/// Creates a literal list expression from [values].
LiteralListExpression literalList(Iterable<Object?> values,
        [Reference? type]) =>
    LiteralListExpression._(false, values.toList(), type);

/// Creates a literal `const` list expression from [values].
LiteralListExpression literalConstList(List<Object?> values,
        [Reference? type]) =>
    LiteralListExpression._(true, values, type);

/// Creates a literal set expression from [values].
LiteralSetExpression literalSet(Iterable<Object?> values, [Reference? type]) =>
    LiteralSetExpression._(false, values.toSet(), type);

/// Creates a literal `const` set expression from [values].
LiteralSetExpression literalConstSet(Set<Object?> values, [Reference? type]) =>
    LiteralSetExpression._(true, values, type);

/// Create a literal map expression from [values].
LiteralMapExpression literalMap(
  Map<Object?, Object?> values, [
  Reference? keyType,
  Reference? valueType,
]) =>
    LiteralMapExpression._(false, values, keyType, valueType);

/// Create a literal `const` map expression from [values].
LiteralMapExpression literalConstMap(
  Map<Object?, Object?> values, [
  Reference? keyType,
  Reference? valueType,
]) =>
    LiteralMapExpression._(true, values, keyType, valueType);

/// Create a literal record expression from [positionalFieldValues] and
/// [namedFieldValues].
LiteralRecordExpression literalRecord(List<Object?> positionalFieldValues,
        Map<String, Object?> namedFieldValues) =>
    LiteralRecordExpression._(false, positionalFieldValues, namedFieldValues);

/// Create a literal `const` record expression from [positionalFieldValues] and
/// [namedFieldValues].
LiteralRecordExpression literalConstRecord(List<Object?> positionalFieldValues,
        Map<String, Object?> namedFieldValues) =>
    LiteralRecordExpression._(true, positionalFieldValues, namedFieldValues);

/// Represents a literal value in Dart source code.
///
/// For example, `LiteralExpression('null')` should emit `null`.
///
/// Some common literals and helpers are available as methods/fields:
/// * [literal]
/// * [literalBool] and [literalTrue], [literalFalse]
/// * [literalNull]
/// * [literalList] and [literalConstList]
/// * [literalSet] and [literalConstSet]
class LiteralExpression extends Expression {
  final String literal;

  const LiteralExpression._(this.literal);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralExpression(this, context);

  @override
  String toString() => literal;
}

class LiteralSpreadExpression extends LiteralExpression {
  LiteralSpreadExpression._(bool nullAware)
      : super._('...${nullAware ? '?' : ''}');
}

class LiteralListExpression extends Expression {
  @override
  final bool isConst;
  final List<Object?> values;
  final Reference? type;

  const LiteralListExpression._(this.isConst, this.values, this.type);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralListExpression(this, context);

  @override
  String toString() => '[${values.map(literal).join(', ')}]';
}

class LiteralSetExpression extends Expression {
  @override
  final bool isConst;
  final Set<Object?> values;
  final Reference? type;

  const LiteralSetExpression._(this.isConst, this.values, this.type);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralSetExpression(this, context);

  @override
  String toString() => '{${values.map(literal).join(', ')}}';
}

class LiteralMapExpression extends Expression {
  @override
  final bool isConst;
  final Map<Object?, Object?> values;
  final Reference? keyType;
  final Reference? valueType;

  const LiteralMapExpression._(
    this.isConst,
    this.values,
    this.keyType,
    this.valueType,
  );

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralMapExpression(this, context);

  @override
  String toString() => '{$values}';
}

class LiteralRecordExpression extends Expression {
  @override
  final bool isConst;
  final List<Object?> positionalFieldValues;
  final Map<String, Object?> namedFieldValues;

  const LiteralRecordExpression._(
      this.isConst, this.positionalFieldValues, this.namedFieldValues);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralRecordExpression(this, context);

  @override
  String toString() {
    final allFields = positionalFieldValues.map((v) => v.toString()).followedBy(
        namedFieldValues.entries.map((e) => '${e.key}: ${e.value}'));
    return '(${allFields.join(', ')})';
  }
}
