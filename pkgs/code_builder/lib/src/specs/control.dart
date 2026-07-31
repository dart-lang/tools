// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../base.dart';
import 'code.dart';
import 'expression.dart';
import 'reference.dart';

part 'control.g.dart';
part '../mixins/control.dart';

part './control/loops.dart';
part './control/branches.dart';
part './control/handling.dart';
part './control/switch.dart';

@immutable
@internal
class ControlBlock {
  /// The full control-flow expression that precedes this block.
  final BaseControlExpression expression;

  /// The body of this block.
  ///
  /// *Note: will always be wrapped in `{`braces`}`*.
  final Code? body;

  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  final String? label;

  const ControlBlock({required this.expression, this.body, this.label});

  ControlBlock.from(ControlBody block, this.expression)
    : body = block.body,
      label = null;

  ControlBlock.fromLabelled(ControlLabel block, this.expression)
    : body = block.body,
      label = block.label;
}

/// Knowledge of different types of control blocks.
///
@internal
abstract class ControlBlockVisitor<T>
    implements ExpressionVisitor<T>, CodeVisitor<T> {
  T visitWhileLoop(WhileLoop loop, [T? context]);
  T visitForInLoop(ForInLoop loop, [T? context]);
  T visitForLoop(ForLoop loop, [T? context]);
  T visitTryCatch(TryCatch block, [T? context]);
  T visitConditional(Conditional block, [T? context]);
  T visitControlExpression(ControlExpression expression, [T? context]);
  T visitSwitchExpression(SwitchExpression block, [T? context]);
  T visitSwitchStatement(SwitchStatement block, [T? context]);
}

/// Knowledge of how to write valid Dart code from [ControlBlockVisitor].
///
@internal
abstract mixin class ControlBlockEmitter
    implements ControlBlockVisitor<StringSink> {
  StringSink _visitControlBlock(ControlBlock block, StringSink? output) {
    output ??= StringBuffer();

    if (block.label != null) {
      output.writeln('${block.label!}:');
    }

    block.expression.accept(this, output);

    output.writeln(' {');
    block.body?.accept(this, output);
    output.write(' }');

    return output;
  }

  @override
  StringSink visitWhileLoop(WhileLoop loop, [StringSink? output]) {
    output ??= StringBuffer();

    final expression = BaseControlExpression.whileLoop(loop.condition);

    _visitControlBlock(
      ControlBlock.fromLabelled(
        loop,
        loop.doWhile == true ? BaseControlExpression.doStatement : expression,
      ),
      output,
    );

    if (loop.doWhile != true) return output;

    output.write(' ');
    expression.statement.accept(this, output);
    output.writeln();
    return output;
  }

  @override
  StringSink visitForInLoop(ForInLoop loop, [StringSink? output]) =>
      _visitControlBlock(
        ControlBlock.fromLabelled(
          loop,
          loop.async == true
              ? BaseControlExpression.awaitForLoop(loop.variable, loop.object)
              : BaseControlExpression.forInLoop(loop.variable, loop.object),
        ),
        output,
      );

  @override
  StringSink visitForLoop(ForLoop loop, [StringSink? output]) =>
      _visitControlBlock(
        ControlBlock.fromLabelled(
          loop,
          BaseControlExpression.forLoop(
            loop.initialize,
            loop.condition,
            loop.advance,
          ),
        ),
        output,
      );

  @visibleForTesting
  BaseControlExpression visitCatchBlock(CatchBlock block) {
    if (block.type == null) {
      return BaseControlExpression.catchStatement(
        block.exception ?? '_',
        block.stacktrace,
      );
    }

    // omit catch clause if exception and stacktrace are unspecified
    if (block.exception == null && block.stacktrace == null) {
      return BaseControlExpression.onStatement(block.type!);
    }

    return BaseControlExpression.onStatement(
      block.type!,
      BaseControlExpression.catchStatement(
        block.exception ?? '_',
        block.stacktrace,
      ),
    );
  }

  @override
  StringSink visitTryCatch(TryCatch block, [StringSink? output]) => _visitAll(
    (() sync* {
      yield ControlBlock.from(block, BaseControlExpression.tryStatement);

      yield* block.handlers.map(
        (h) => ControlBlock.from(h, visitCatchBlock(h)),
      );

      if (block.handleAll == null) return;

      yield ControlBlock(
        expression: BaseControlExpression.finallyStatement,
        body: block.handleAll,
      );
    })(),
    output,
  );

  StringSink _visitAll(Iterable<ControlBlock> blocks, StringSink? output) {
    output ??= StringBuffer();

    for (final block in blocks) {
      _visitControlBlock(block, output);
      output.write(' ');
    }

    return output;
  }

  BaseControlExpression _visitBranch(Branch branch, bool first) {
    final condition =
        branch.condition != null
            ? BaseControlExpression.ifStatement(branch.condition!)
            : null;

    if (first) {
      return condition ??
          (throw ArgumentError(
            'The first branch in a conditional must specify a condition',
            'condition',
          ));
    }

    return BaseControlExpression.elseStatement(condition);
  }

  @override
  StringSink visitConditional(Conditional block, [StringSink? output]) =>
      _visitAll(
        block.branches.mapIndexed(
          (index, branch) =>
              ControlBlock.from(branch, _visitBranch(branch, index == 0)),
        ),
        output,
      );

  @override
  StringSink visitControlExpression(
    ControlExpression expression, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();

    output.write(expression.control);

    if (expression.body == null || expression.body!.isEmpty) {
      return output;
    }

    final body = expression.body!; // convenience

    output.write(' ');
    if (expression.parenthesised) {
      output.write('(');
    }

    if (body.length == 1) {
      body.first?.accept(this, output);
      if (expression.parenthesised) {
        output.write(')');
      }

      return output;
    }

    if (expression.separator == null) {
      throw ArgumentError(
        'A separator must be provided when body contains '
            'multiple expressions.',
        'separator',
      );
    }

    final separator = expression.separator!; // convenience

    for (var i = 0; i < body.length; i++) {
      final expression = body[i];

      if (i != 0 && expression != null) {
        output.write(' ');
      }

      expression?.accept(this, output);

      if (i == body.length - 1) continue; // no separator after last item

      output.write(separator);
    }

    if (expression.parenthesised) {
      output.write(')');
    }

    return output;
  }

  @override
  StringSink visitSwitchExpression(
    SwitchExpression block, [
    StringSink? output,
  ]) {
    output ??= StringBuffer();

    BaseControlExpression.switchStatement(block.value).accept(this, output);

    output.writeln(' {');

    for (final item in block.cases) {
      _visitCaseExpression(item, output);
    }

    output.write(' }');

    return output;
  }

  @override
  StringSink visitSwitchStatement(SwitchStatement block, [StringSink? output]) {
    output ??= StringBuffer();

    BaseControlExpression.switchStatement(block.value).accept(this, output);

    output.writeln(' {');

    for (final item in block.cases) {
      _visitCaseStatement(item, output);
    }

    output.write(' }');

    return output;
  }

  StringSink _visitCaseStatement(Case<Code?> statement, StringSink output) {
    if (statement.label case final String label) {
      output.writeln('$label:');
    }

    if (statement.isDefault == true) {
      output.writeln('default:');
    } else {
      output.write('case ');
      statement.pattern!.accept(this, output);

      if (statement.guard case final Expression guard) {
        output.write(' when ');
        guard.accept(this, output);
      }

      output.writeln(':');
    }

    if (statement.body case final Code body) {
      body.accept(this, output);
    }

    return output;
  }

  StringSink _visitCaseExpression(
    Case<Expression> expression,
    StringSink output,
  ) {
    (expression.isDefault == true ? Expression.wildcard : expression.pattern!)
        .accept(this, output);

    if (expression.guard case final Expression guard) {
      output.write(' when ');
      guard.accept(this, output);
    }

    output.write(' => ');

    if (expression.body == null) {
      throw ArgumentError(
        'Cases in `switch` expressions must provide '
            'a non-null body.',
        'body',
      );
    }

    expression.body!.accept(this, output);
    output.writeln(',');

    return output;
  }
}
