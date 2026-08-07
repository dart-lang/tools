// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import '../allocator.dart';
import '../base.dart';
import '../visitors.dart';
import 'expression.dart';
import 'expression.dart' as expr;
import 'reference.dart';
import 'reference.dart' as ref;

part 'pattern/binary.dart';
part 'pattern/constant.dart';
part 'pattern/destructuring.dart';
part 'pattern/relational.dart';
part 'pattern/unary.dart';
part 'pattern/variable.dart';

/// A Dart pattern for pattern matching and destructuring.
///
/// See https://dart.dev/language/patterns and the Dart 3 Patterns specification.
abstract class Pattern implements Spec {
  const Pattern();

  @override
  R accept<R>(covariant PatternVisitor<R> visitor, [R? context]);

  /// Logical-or pattern: `this || other`.
  Pattern or(Pattern other) => BinaryPattern._(this, other, '||');

  /// Logical-and pattern: `this && other`.
  Pattern and(Pattern other) => BinaryPattern._(this, other, '&&');

  /// Cast pattern: `this as type`.
  Pattern asA(Reference type) => CastPattern._(this, type);

  /// Null-check pattern: `this?`.
  Pattern get nullChecked => UnaryPattern._(this, '?');

  /// Null-assert pattern: `this!`.
  Pattern get nullAsserted => UnaryPattern._(this, '!');

  /// Parenthesized pattern: `(this)`.
  Pattern get parenthesized => ParenthesizedPattern._(this);

  /// Wildcard pattern: `_`.
  static const wildcard = WildcardPattern._();

  /// Variable pattern: `var name` or `type name`.
  static VariablePattern var_(String name, {Reference? type}) =>
      VariablePattern._(name, type: type, isVar: type == null);

  /// Variable pattern: `final name` or `final type name`.
  static VariablePattern final_(String name, {Reference? type}) =>
      VariablePattern._(name, type: type, isFinal: true);

  /// Typed variable pattern: `type name`.
  static VariablePattern typed(String name, Reference type) =>
      VariablePattern._(name, type: type);

  /// Variable pattern: `var name` or `final name` or `Type name`.
  static VariablePattern variable(
    String name, {
    Reference? type,
    bool isFinal = false,
    bool isVar = false,
  }) => VariablePattern._(
    name,
    type: type,
    isFinal: isFinal,
    isVar: isVar || (!isFinal && type == null),
  );

  /// Constant pattern from [expression].
  static ConstantPattern constant(
    Expression expression, {
    bool isConst = false,
  }) => ConstantPattern._(expression, isConst: isConst);

  /// Constant pattern from a literal [value].
  static ConstantPattern literal(Object? value) =>
      ConstantPattern._(expr.literal(value));

  /// Constant pattern referencing [name].
  static ConstantPattern refer(String name, [String? url]) =>
      ConstantPattern._(ref.refer(name, url));

  /// Relational pattern with [operator] and [operand].
  static RelationalPattern relational(String operator, Expression operand) =>
      RelationalPattern._(operator, operand);

  /// Equality pattern: `== operand`.
  static RelationalPattern equalTo(Expression operand) =>
      RelationalPattern._('==', operand);

  /// Inequality pattern: `!= operand`.
  static RelationalPattern notEqualTo(Expression operand) =>
      RelationalPattern._('!=', operand);

  /// Greater-than pattern: `> operand`.
  static RelationalPattern greaterThan(Expression operand) =>
      RelationalPattern._('>', operand);

  /// Less-than pattern: `< operand`.
  static RelationalPattern lessThan(Expression operand) =>
      RelationalPattern._('<', operand);

  /// Greater-or-equal pattern: `>= operand`.
  static RelationalPattern greaterOrEqualTo(Expression operand) =>
      RelationalPattern._('>=', operand);

  /// Less-or-equal pattern: `<= operand`.
  static RelationalPattern lessOrEqualTo(Expression operand) =>
      RelationalPattern._('<=', operand);

  /// List pattern: `[p1, p2, ...rest]`.
  static ListPattern list(
    Iterable<Pattern> elements, {
    Reference? type,
    Pattern? rest,
    int? restIndex,
  }) => ListPattern._(
    elements.toList(),
    type: type,
    rest: rest,
    restIndex: restIndex ?? (rest != null ? elements.length : null),
  );

  /// Map pattern: `{'key': pattern}`.
  static MapPattern map(
    Map<Expression, Pattern> entries, {
    Reference? keyType,
    Reference? valueType,
  }) => MapPattern._(
    entries.entries.map((e) => MapPatternEntry(e.key, e.value)).toList(),
    keyType: keyType,
    valueType: valueType,
  );

  /// Record pattern: `(p1, name: p2)`.
  static RecordPattern record({
    Iterable<Pattern> positional = const [],
    Map<String, Pattern> named = const {},
  }) => RecordPattern._(positional: positional.toList(), named: named);

  /// Object pattern: `SomeClass(p1, name: p2)`.
  static ObjectPattern object(
    Reference type, {
    Iterable<Pattern> positional = const [],
    Map<String, Pattern> named = const {},
  }) => ObjectPattern._(type, positional: positional.toList(), named: named);
}

/// Knowledge of different types of patterns in Dart.
abstract class PatternVisitor<T>
    implements SpecVisitor<T>, ExpressionVisitor<T> {
  T visitBinaryPattern(BinaryPattern pattern, [T? context]);
  T visitUnaryPattern(UnaryPattern pattern, [T? context]);
  T visitCastPattern(CastPattern pattern, [T? context]);
  T visitRelationalPattern(RelationalPattern pattern, [T? context]);
  T visitConstantPattern(ConstantPattern pattern, [T? context]);
  T visitVariablePattern(VariablePattern pattern, [T? context]);
  T visitWildcardPattern(WildcardPattern pattern, [T? context]);
  T visitParenthesizedPattern(ParenthesizedPattern pattern, [T? context]);
  T visitListPattern(ListPattern pattern, [T? context]);
  T visitMapPattern(MapPattern pattern, [T? context]);
  T visitRecordPattern(RecordPattern pattern, [T? context]);
  T visitObjectPattern(ObjectPattern pattern, [T? context]);
  T visitIfCaseExpression(IfCaseExpression expression, [T? context]);
}

/// Knowledge of how to write valid Dart code from [PatternVisitor].
abstract mixin class PatternEmitter implements PatternVisitor<StringSink> {
  @protected
  Allocator get allocator;

  @override
  StringSink visitBinaryPattern(BinaryPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    pattern.left.accept(this, output);
    output.write(' ${pattern.operator} ');
    pattern.right.accept(this, output);
    return output;
  }

  @override
  StringSink visitUnaryPattern(UnaryPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    pattern.pattern.accept(this, output);
    output.write(pattern.operator);
    return output;
  }

  @override
  StringSink visitCastPattern(CastPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    pattern.pattern.accept(this, output);
    output.write(' as ');
    pattern.type.accept(this, output);
    return output;
  }

  @override
  StringSink visitRelationalPattern(
    RelationalPattern pattern, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    output.write('${pattern.operator} ');
    pattern.operand.accept(this, output);
    return output;
  }

  @override
  StringSink visitConstantPattern(
    ConstantPattern pattern, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    if (pattern.isConst) {
      output.write('const (');
      pattern.expression.accept(this, output);
      output.write(')');
    } else {
      pattern.expression.accept(this, output);
    }
    return output;
  }

  @override
  StringSink visitVariablePattern(
    VariablePattern pattern, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    if (pattern.isFinal) {
      output.write('final ');
    }
    if (pattern.isVar) {
      output.write('var ');
    }
    if (pattern.type != null) {
      pattern.type!.accept(this, output);
      output.write(' ');
    }
    output.write(pattern.name);
    return output;
  }

  @override
  StringSink visitWildcardPattern(
    WildcardPattern pattern, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    output.write('_');
    return output;
  }

  @override
  StringSink visitParenthesizedPattern(
    ParenthesizedPattern pattern, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    output.write('(');
    pattern.pattern.accept(this, output);
    output.write(')');
    return output;
  }

  @override
  StringSink visitListPattern(ListPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    if (pattern.type != null) {
      output.write('<');
      pattern.type!.accept(this, output);
      output.write('>');
    }
    output.write('[');
    final elements = pattern.elements;
    final restIndex = pattern.restIndex;
    final hasRest = pattern.hasRest;

    final count = elements.length + (hasRest ? 1 : 0);
    var elementIdx = 0;

    for (var i = 0; i < count; i++) {
      if (i > 0) output.write(', ');
      if (hasRest && i == restIndex) {
        output.write('...');
        if (pattern.rest != null) {
          pattern.rest!.accept(this, output);
        }
      } else {
        elements[elementIdx++].accept(this, output);
      }
    }
    output.write(']');
    return output;
  }

  @override
  StringSink visitMapPattern(MapPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    if (pattern.keyType != null && pattern.valueType != null) {
      output.write('<');
      pattern.keyType!.accept(this, output);
      output.write(', ');
      pattern.valueType!.accept(this, output);
      output.write('>');
    }
    output.write('{');
    for (var i = 0; i < pattern.entries.length; i++) {
      if (i > 0) output.write(', ');
      final entry = pattern.entries[i];
      entry.key.accept(this, output);
      output.write(': ');
      entry.value.accept(this, output);
    }
    output.write('}');
    return output;
  }

  @override
  StringSink visitRecordPattern(RecordPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    output.write('(');
    var first = true;
    for (final p in pattern.positional) {
      if (!first) output.write(', ');
      p.accept(this, output);
      first = false;
    }
    for (final entry in pattern.named.entries) {
      if (!first) output.write(', ');
      output.write('${entry.key}: ');
      entry.value.accept(this, output);
      first = false;
    }
    output.write(')');
    return output;
  }

  @override
  StringSink visitObjectPattern(ObjectPattern pattern, [StringSink? output]) {
    output ??= StringBuffer();
    pattern.type.accept(this, output);
    output.write('(');
    var first = true;
    for (final p in pattern.positional) {
      if (!first) output.write(', ');
      p.accept(this, output);
      first = false;
    }
    for (final entry in pattern.named.entries) {
      if (!first) output.write(', ');
      output.write('${entry.key}: ');
      entry.value.accept(this, output);
      first = false;
    }
    output.write(')');
    return output;
  }

  @override
  StringSink visitIfCaseExpression(
    IfCaseExpression expression, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    expression.object.accept(this, output);
    output.write(' case ');
    expression.pattern.accept(this, output);
    if (expression.guard != null) {
      output.write(' when ');
      expression.guard!.accept(this, output);
    }
    return output;
  }
}
