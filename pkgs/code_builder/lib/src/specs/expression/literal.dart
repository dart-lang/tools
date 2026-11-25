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
/// Returns an expression for a string formatted `'<value>'`.
///
/// If [raw] is `true` returns an expression that will evaluate to a String
/// containing exactly the same content as [value]. The literal may use single
/// or double quotes, and may not actually be marked raw, depending on the
/// content. All disallowed characters are automatically escaped.
///
/// Passing `raw: true` is recommended and will become the only option in a
/// future release.
Expression literalString(String value, {bool raw = false}) {
  if (raw) return LiteralExpression._(_escapeString(value, preferRaw: raw));
  final escaped = value.replaceAll('\'', '\\\'').replaceAll('\n', '\\n');
  return LiteralExpression._("'$escaped'");
}

String _escapeString(String value, {bool preferRaw = false}) {
  final original = value;
  var hasSingleQuote = false;
  var hasDoubleQuote = false;
  var hasDollar = false;
  var hasBackslash = false;
  var canBeRaw = true;

  value = value.replaceAllMapped(_escapeRegExp, (match) {
    final char = match[0]!;
    if (char == "'") {
      hasSingleQuote = true;
      return char;
    } else if (char == '"') {
      hasDoubleQuote = true;
      return char;
    } else if (char == r'$') {
      hasDollar = true;
      return char;
    } else if (char == r'\') {
      hasBackslash = true;
      return r'\\';
    }

    canBeRaw = false;
    return _escapeMap[char] ?? _hexLiteral(char);
  });

  if (preferRaw && canBeRaw && !hasSingleQuote) {
    return "r'$original'";
  }

  if (canBeRaw && (hasDollar || hasBackslash)) {
    if (!hasSingleQuote) return "r'$original'";
    if (!hasDoubleQuote) return 'r"$original"';
  }

  if (!hasDollar) {
    if (!hasSingleQuote) return "'$value'";
    if (!hasDoubleQuote) return '"$value"';
  }

  value = value.replaceAll(_dollarQuoteRegexp, r'\');
  return "'$value'";
}

/// Given single-character string, return the hex-escaped equivalent.
String _hexLiteral(String input) {
  final value = input.runes.single
      .toRadixString(16)
      .toUpperCase()
      .padLeft(2, '0');
  return '\\x$value';
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
};

/// A [RegExp] that matches whitespace characters that must be escaped and
/// single-quote, double-quote, and `$`
final _escapeRegExp = RegExp('[\$\'"\\x00-\\x07\\x0E-\\x1F$_escapeMapRegexp]');

// _escapeMap.keys.map(_hexLiteral).join();
const _escapeMapRegexp = r'\x08\x09\x0A\x0B\x0C\x0D\x7F\x5C';

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

/// Creates a literal map expression from collection [elements].
///
/// Unlike [literalMap], which accepts a Dart [Map] of key-value pairs,
/// [literalMapElements] accepts arbitrary collection [Spec] elements so callers
/// can interleave [MapLiteralEntry] items (including null-aware keys and
/// values), spreads ([Expression.spread], [Expression.nullSafeSpread]), and
/// control-flow elements in order:
/// ```dart
/// literalMapElements([
///   refer('defaults').spread,
///   MapLiteralEntry(literalString('id'), refer('id')),
///   MapLiteralEntry(
///     literalString('nickname'),
///     refer('nickname'),
///     nullAwareValue: true,
///   ),
/// ])
/// ```
LiteralMapElementsExpression literalMapElements(
  Iterable<Spec> elements, [
  Reference? keyType,
  Reference? valueType,
]) => LiteralMapElementsExpression._(
  false,
  List<Spec>.unmodifiable(elements),
  keyType,
  valueType,
);

/// Creates a literal `const` map expression from collection [elements].
///
/// Like [literalMapElements], this accepts collection [Spec] elements such as
/// [MapLiteralEntry] and spreads, while emitting a `const` map literal and
/// eliding redundant `const` keywords on nested constant expressions:
/// ```dart
/// literalConstMapElements([
///   MapLiteralEntry(
///     literalString('zero'),
///     refer('Duration').constInstance([]),
///   ),
/// ]) // const {'zero': Duration()}
/// ```
LiteralMapElementsExpression literalConstMapElements(
  Iterable<Spec> elements, [
  Reference? keyType,
  Reference? valueType,
]) => LiteralMapElementsExpression._(
  true,
  List<Spec>.unmodifiable(elements),
  keyType,
  valueType,
);

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
  String toString() =>
      '[${values.map((v) => v is Spec ? v : literal(v)).join(', ')}]';
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
  String toString() =>
      '{${values.map((v) => v is Spec ? v : literal(v)).join(', ')}}';
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

/// A `key: value` entry element inside [literalMapElements] or
/// [literalConstMapElements].
///
/// Unlike entries in [literalMap], [MapLiteralEntry] is a [Spec] rather than a
/// Dart [Map] entry, allowing it to be interleaved with spreads and
/// control-flow elements and to mark [key] or [value] as null-aware (`?key`,
/// `?value`) so the entry is omitted when a nullable expression evaluates to
/// `null`:
/// ```dart
/// literalMapElements([
///   MapLiteralEntry(literalString('id'), refer('id')),
///   MapLiteralEntry(
///     literalString('label'),
///     refer('label'),
///     nullAwareValue: true,
///   ),
/// ]) // {'id': id, 'label': ?label, }
/// ```
class MapLiteralEntry implements Spec {
  /// The key expression emitted before `:` in this entry.
  final Expression key;

  /// The value expression emitted after `:` in this entry.
  final Expression value;

  /// Whether [key] is prefixed with `?` (`?key: value`), omitting this entry
  /// when [key] evaluates to `null`.
  final bool nullAwareKey;

  /// Whether [value] is prefixed with `?` (`key: ?value`), omitting this entry
  /// when [value] evaluates to `null`.
  final bool nullAwareValue;

  /// Creates a `key: value` map literal element.
  const MapLiteralEntry(
    this.key,
    this.value, {
    this.nullAwareKey = false,
    this.nullAwareValue = false,
  });

  @override
  R accept<R>(covariant ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitMapLiteralEntry(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}

/// A map literal expression constructed from collection [Spec] [elements].
///
/// Use [literalMapElements] or [literalConstMapElements] to build map literals
/// containing [MapLiteralEntry] items, spreads ([Expression.spread],
/// [Expression.nullSafeSpread]), or control-flow elements that cannot be
/// represented in [LiteralMapExpression]:
/// ```dart
/// literalMapElements(
///   [MapLiteralEntry(literalString('count'), literalNum(1))],
///   refer('String'),
///   refer('int'),
/// ) // <String, int>{'count': 1}
/// ```
class LiteralMapElementsExpression extends Expression {
  @override
  final bool isConst;

  /// The ordered collection elements (such as [MapLiteralEntry], spreads, or
  /// control-flow elements) emitted inside `{...}`.
  final List<Spec> elements;

  /// Optional explicit key type argument; defaults to `dynamic` when omitted
  /// alongside a non-null [valueType].
  final Reference? keyType;

  /// Optional explicit value type argument; defaults to `dynamic` when omitted
  /// alongside a non-null [keyType].
  final Reference? valueType;

  const LiteralMapElementsExpression._(
    this.isConst,
    this.elements,
    this.keyType,
    this.valueType,
  );

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitLiteralMapElementsExpression(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
}

/// A null-aware collection element (`?value`) for use in list and set literals.
///
/// Wrapping an [Expression] in [NullAwareElement] (or via
/// [Expression.nullAwareElement]) emits `?value` inside [literalList],
/// [literalConstList], [literalSet], or [literalConstSet] so the element is
/// omitted when [value] evaluates to `null`. Implements [Spec] rather than
/// [Expression] because `?value` is valid only in collection element positions:
/// ```dart
/// literalSet([refer('maybeTag').nullAwareElement]) // {?maybeTag}
/// ```
class NullAwareElement implements Spec {
  /// The expression evaluated and inserted into the collection if non-null.
  final Expression value;

  /// Creates a null-aware element wrapping [value].
  ///
  /// [Expression.nullAwareElement] is the fluent form.
  const NullAwareElement(this.value);

  @override
  R accept<R>(covariant ExpressionVisitor<R> visitor, [R? context]) =>
      visitor.visitNullAwareElement(this, context);

  @override
  String toString() => accept(DartEmitter()).toString();
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
