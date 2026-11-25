// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:meta/meta.dart';

import '../allocator.dart';
import '../base.dart';
import '../emitter.dart';
import 'code.dart';
import 'expression.dart';
import 'pattern.dart';
import 'reference.dart';

part 'control.g.dart';
part 'control/branches.dart';
part 'control/elements.dart';
part 'control/handling.dart';
part 'control/loops.dart';
part 'control/switch.dart';

/// Knowledge of different types of control flow constructs in Dart.
abstract class ControlVisitor<T>
    implements CodeVisitor<T>, ExpressionVisitor<T>, PatternVisitor<T> {
  T visitForLoop(ForLoop spec, [T? context]);
  T visitForInLoop(ForInLoop spec, [T? context]);
  T visitWhileLoop(WhileLoop spec, [T? context]);
  T visitConditional(Conditional spec, [T? context]);
  T visitBooleanCondition(BooleanCondition condition, [T? context]);
  T visitCaseCondition(CaseCondition condition, [T? context]);
  T visitIfElement(IfElement spec, [T? context]);
  T visitForLoopElement(ForLoopElement spec, [T? context]);
  T visitForInElement(ForInElement spec, [T? context]);
  T visitTry(Try spec, [T? context]);
  T visitSwitchStatement(SwitchStatement spec, [T? context]);
  T visitSwitchExpression(SwitchExpression spec, [T? context]);
}

/// Knowledge of how to write valid Dart code from [ControlVisitor].
abstract mixin class ControlEmitter implements ControlVisitor<StringSink> {
  @protected
  Allocator get allocator;

  @override
  StringSink visitBooleanCondition(
    BooleanCondition condition, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    condition.expression.accept(this, output);
    return output;
  }

  @override
  StringSink visitCaseCondition(CaseCondition condition, [StringSink? output]) {
    output ??= StringBuffer();
    condition.object.accept(this, output);
    output.write(' case ');
    condition.pattern.accept(this, output);
    if (condition.guard != null) {
      output.write(' when ');
      condition.guard!.accept(this, output);
    }
    return output;
  }

  @override
  StringSink visitIfElement(IfElement spec, [StringSink? output]) {
    output ??= StringBuffer();
    output.write('if (');
    spec.condition.accept(this, output);
    output.write(') ');
    final orElse = spec.orElse;
    if (orElse == null) {
      spec.then.accept(this, output);
      return output;
    }
    _writeThenBeforeElse(spec.then, output);
    output.write(' else ');
    orElse.accept(this, output);
    return output;
  }

  /// Writes [then] so that a following `else` parses.
  ///
  /// Dart reads a nullable type followed by `else` (`if (c) x is int? else y`)
  /// as the start of a conditional expression, so a trailing expression whose
  /// emitted text ends in `?` is wrapped in parentheses.
  void _writeThenBeforeElse(Spec then, StringSink output) {
    final text = then.accept<StringSink>(this, StringBuffer()).toString();
    final tail = text.endsWith('?') ? _trailingExpression(then) : null;
    final tailText = tail?.accept<StringSink>(this, StringBuffer()).toString();
    if (tailText == null || !text.endsWith(tailText)) {
      output.write(text);
      return;
    }
    output
      ..write(text.substring(0, text.length - tailText.length))
      ..write('(')
      ..write(tailText)
      ..write(')');
  }

  /// The expression emitted last by [element], if it can be determined.
  static Expression? _trailingExpression(Spec element) => switch (element) {
    IfElement(:final then, :final orElse) => _trailingExpression(
      orElse ?? then,
    ),
    ForElement(:final body) => _trailingExpression(body),
    MapLiteralEntry(:final value) || NullAwareElement(:final value) => value,
    BinaryExpression(
      left: LiteralExpression(literal: '...' || '...?'),
      :final right,
    ) =>
      right,
    Expression() => element,
    _ => null,
  };

  @override
  StringSink visitForLoopElement(ForLoopElement spec, [StringSink? output]) {
    output ??= StringBuffer();
    output.write('for (');
    spec.initialize?.accept(this, output);
    output.write(';');
    if (spec.condition != null) {
      output.write(' ');
      spec.condition!.accept(this, output);
    }
    output.write(';');
    if (spec.advance != null) {
      output.write(' ');
      spec.advance!.accept(this, output);
    }
    output.write(') ');
    spec.body.accept(this, output);
    return output;
  }

  @override
  StringSink visitForInElement(ForInElement spec, [StringSink? output]) {
    output ??= StringBuffer();
    if (spec.async) {
      output.write('await ');
    }
    output.write('for (');
    spec.variable.accept(this, output);
    output.write(' in ');
    spec.object.accept(this, output);
    output.write(') ');
    spec.body.accept(this, output);
    return output;
  }

  @override
  StringSink visitForLoop(ForLoop loop, [StringSink? output]) {
    output ??= StringBuffer();
    if (loop.label != null) {
      output.writeln('${loop.label}:');
    }
    output.write('for (');
    if (loop.initialize != null) {
      loop.initialize!.accept(this, output);
    }
    output.write('; ');
    if (loop.condition != null) {
      loop.condition!.accept(this, output);
    }
    output.write('; ');
    if (loop.advance != null) {
      loop.advance!.accept(this, output);
    }
    output.writeln(') {');
    if (loop.body != null) {
      loop.body!.accept(this, output);
    }
    output.write(' }');
    return output;
  }

  @override
  StringSink visitForInLoop(ForInLoop loop, [StringSink? output]) {
    output ??= StringBuffer();
    if (loop.label != null) {
      output.writeln('${loop.label}:');
    }
    if (loop.async) {
      output.write('await ');
    }
    output.write('for (');
    loop.variable.accept(this, output);
    output.write(' in ');
    loop.object.accept(this, output);
    output.writeln(') {');
    if (loop.body != null) {
      loop.body!.accept(this, output);
    }
    output.write(' }');
    return output;
  }

  @override
  StringSink visitWhileLoop(WhileLoop loop, [StringSink? output]) {
    output ??= StringBuffer();
    if (loop.label != null) {
      output.writeln('${loop.label}:');
    }
    if (loop.doWhile) {
      output.writeln('do {');
      if (loop.body != null) {
        loop.body!.accept(this, output);
      }
      output.write(' } while (');
      loop.condition.accept(this, output);
      output.write(');');
    } else {
      output.write('while (');
      loop.condition.accept(this, output);
      output.writeln(') {');
      if (loop.body != null) {
        loop.body!.accept(this, output);
      }
      output.write(' }');
    }
    return output;
  }

  @override
  StringSink visitConditional(Conditional conditional, [StringSink? output]) {
    output ??= StringBuffer();
    for (var i = 0; i < conditional.branches.length; i++) {
      final branch = conditional.branches[i];
      if (i == 0) {
        output.write('if (');
      } else {
        output.write(' else if (');
      }
      branch.condition.accept(this, output);
      output.writeln(') {');
      if (branch.body != null) {
        branch.body!.accept(this, output);
      }
      output.write(' }');
    }
    if (conditional.orElse != null) {
      output.writeln(' else {');
      conditional.orElse!.accept(this, output);
      output.write(' }');
    }
    return output;
  }

  @override
  StringSink visitTry(Try spec, [StringSink? output]) {
    output ??= StringBuffer();
    output.writeln('try {');
    if (spec.body != null) {
      spec.body!.accept(this, output);
    }
    output.write(' }');

    for (final catchClause in spec.catches) {
      if (catchClause.on != null) {
        output.write(' on ');
        catchClause.on!.accept(this, output);
      }
      if (catchClause.exception != null || catchClause.stackTrace != null) {
        final ex = catchClause.exception ?? '_';
        final st = catchClause.stackTrace != null
            ? ', ${catchClause.stackTrace}'
            : '';
        output.write(' catch ($ex$st)');
      } else if (catchClause.on == null) {
        output.write(' catch (_)');
      }
      output.writeln(' {');
      if (catchClause.body != null) {
        catchClause.body!.accept(this, output);
      }
      output.write(' }');
    }

    if (spec.finallyBlock != null) {
      output.writeln(' finally {');
      spec.finallyBlock!.accept(this, output);
      output.write(' }');
    }
    return output;
  }

  @override
  StringSink visitSwitchStatement(
    SwitchStatement statement, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    if (statement.label != null) {
      output.writeln('${statement.label}:');
    }
    output.write('switch (');
    statement.value.accept(this, output);
    output.writeln(') {');

    for (final c in statement.cases) {
      if (c.label != null) {
        output.writeln('${c.label}:');
      }
      output.write('case ');
      c.pattern.accept(this, output);
      if (c.guard != null) {
        output.write(' when ');
        c.guard!.accept(this, output);
      }
      output.writeln(':');
      if (c.body != null) {
        c.body!.accept(this, output);
      }
    }

    if (statement.defaultCase != null) {
      output.writeln('default:');
      statement.defaultCase!.accept(this, output);
    }

    output.write(' }');
    return output;
  }

  @override
  StringSink visitSwitchExpression(
    SwitchExpression expression, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();
    output.write('switch (');
    expression.value.accept(this, output);
    output.writeln(') {');

    for (final c in expression.cases) {
      c.pattern.accept(this, output);
      if (c.guard != null) {
        output.write(' when ');
        c.guard!.accept(this, output);
      }
      output.write(' => ');
      c.body.accept(this, output);
      output.writeln(',');
    }

    output.write(' }');
    return output;
  }
}
