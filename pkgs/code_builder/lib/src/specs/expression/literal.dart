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
/// The _content_ of [value] is used as the _source_ of the generated Dart
/// string wrapped in single quotes. For example, `literalString('\$foo')` will
/// generate `'$foo'`, which will be an interpolation in the generated source.
///
/// If the content of [value] is intended to match the content of the generated
/// literal use the [fullEscape] argument to create a String expression with
/// whatever escaping is necessary to result in the same content. This may
/// result in a raw string.
///
/// To force a raw String use the [raw] argument to create a string formatted
/// `r'<value>'`. For example `literalString('\$foo', raw: true)` will generate
/// `r'$foo'` which includes a `$` character. Most callers will prefer
/// [fullEscape].
///
/// When [raw] is `true`, the value may not contain any single quotes.
/// When [raw] and [fullEscape] are `false`, single quotes are escaped.
///
/// Newlines and carriage returns are always escaped outside of triple quoted
/// strings to avoid invalid syntax.
Expression literalString(
  String value, {
  bool raw = false,
  bool fullEscape = false,
}) {
  if (fullEscape) return LiteralExpression._(_escapeString(value));
  if (raw && value.contains('\'')) {
    throw ArgumentError('Cannot include a single quote in a raw string');
  }
  final escaped = value
      .replaceAll('\'', '\\\'')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
  return LiteralExpression._("${raw ? 'r' : ''}'$escaped'");
}

String _escapeString(String value) {
  var hasSingleQuote = false;
  var hasDoubleQuote = false;
  var hasDollar = false;
  var canBeRaw = true;

  value = value.replaceAllMapped(_escapeRegExp, (match) {
    final value = match[0]!;
    if (value == "'") {
      hasSingleQuote = true;
      return value;
    } else if (value == '"') {
      hasDoubleQuote = true;
      return value;
    } else if (value == r'$') {
      hasDollar = true;
      return value;
    }

    canBeRaw = false;
    return _escapeMap[value] ?? _hexLiteral(value);
  });

  if (!hasDollar) {
    if (!hasSingleQuote) return "'$value'";
    if (!hasDoubleQuote) return '"$value"';
  } else if (canBeRaw) {
    if (!hasSingleQuote) return "r'$value'";
    if (!hasDoubleQuote) return 'r"$value"';
  }
  value = value.replaceAll(_dollarQuoteRegexp, r'\');
  return "'$value'";
}

final _dollarQuoteRegexp = RegExp(r"(?=[$'])");

/// A map from whitespace characters & `\` to their escape sequences.
const _escapeMap = {
  '\b': r'\b', // 08 - backspace
  '\t': r'\t', // 09 - tab
  '\n': r'\n', // 0A - new line
  '\v': r'\v', // 0B - vertical tab
  '\f': r'\f', // 0C - form feed
  '\r': r'\r', // 0D - carriage return
  '\x7F': r'\x7F', // delete
  r'\': r'\\', // backslash
};

/// Given single-character string, return the hex-escaped equivalent.
String _hexLiteral(String input) {
  final value = input.runes.single
      .toRadixString(16)
      .toUpperCase()
      .padLeft(2, '0');
  return '\\x$value';
}

/// A [RegExp] that matches whitespace characters that must be escaped and
/// single-quote, double-quote, and `$`
final _escapeRegExp = RegExp('[\$\'"\\x00-\\x07\\x0E-\\x1F$_escapeMapRegexp]');

final _escapeMapRegexp = _escapeMap.keys.map(_hexLiteral).join();

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
LiteralListExpression literalList(
  Iterable<Object?> values, [
  Reference? type,
]) => LiteralListExpression._(false, values.toList(), type);

/// Creates a literal `const` list expression from [values].
LiteralListExpression literalConstList(
  List<Object?> values, [
  Reference? type,
]) => LiteralListExpression._(true, values, type);

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
]) => LiteralMapExpression._(false, values, keyType, valueType);

/// Create a literal `const` map expression from [values].
LiteralMapExpression literalConstMap(
  Map<Object?, Object?> values, [
  Reference? keyType,
  Reference? valueType,
]) => LiteralMapExpression._(true, values, keyType, valueType);

/// Create a literal record expression from [positionalFieldValues] and
/// [namedFieldValues].
LiteralRecordExpression literalRecord(
  List<Object?> positionalFieldValues,
  Map<String, Object?> namedFieldValues,
) => LiteralRecordExpression._(false, positionalFieldValues, namedFieldValues);

/// Create a literal `const` record expression from [positionalFieldValues] and
/// [namedFieldValues].
LiteralRecordExpression literalConstRecord(
  List<Object?> positionalFieldValues,
  Map<String, Object?> namedFieldValues,
) => LiteralRecordExpression._(true, positionalFieldValues, namedFieldValues);

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
    this.isConst,
    this.positionalFieldValues,
    this.namedFieldValues,
  );

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralRecordExpression(this, context);

  @override
  String toString() {
    final allFields = positionalFieldValues
        .map((v) => v.toString())
        .followedBy(
          namedFieldValues.entries.map((e) => '${e.key}: ${e.value}'),
        );
    return '(${allFields.join(', ')})';
  }
}
