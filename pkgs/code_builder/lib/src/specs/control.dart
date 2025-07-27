// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
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

/// Knowledge of different types of control blocks.
///
@internal
abstract class ControlBlockVisitor<T>
    implements ExpressionVisitor<T>, CodeVisitor<T> {
  T visitControlBlock(ControlBlock block, [T? context]);
  T visitLabeledBlock(LabeledControlBlock block, [T? context]);
  T visitWhileLoop(WhileLoop loop, [T? context]);
  T visitControlTree(ControlTree tree, [T? context]);
  T visitControlExpression(ControlExpression expression, [T? context]);
}

/// Knowledge of how to write valid Dart code from [ControlBlockVisitor].
///
@internal
abstract mixin class ControlBlockEmitter
    implements ControlBlockVisitor<StringSink> {
  @override
  StringSink visitControlBlock(ControlBlock block, [StringSink? output]) {
    output ??= StringBuffer();
    block._expression.accept(this, output);
    output.write(' { ');
    block.body.accept(this, output);
    output.write(' }');
    return output;
  }

  @override
  StringSink visitLabeledBlock(LabeledControlBlock block,
      [StringSink? output]) {
    output ??= StringBuffer();
    if (block.label != null) {
      output.write('${block.label!}: ');
    }

    return visitControlBlock(block, output);
  }

  @override
  StringSink visitWhileLoop(WhileLoop loop, [StringSink? output]) {
    output ??= StringBuffer();
    visitLabeledBlock(loop, output);

    if (loop.doWhile != true) return output;

    output.write(' ');
    loop._statement.statement.accept(this, output);
    return output;
  }

  @override
  StringSink visitControlTree(ControlTree tree, [StringSink? output]) {
    output ??= StringBuffer();

    for (final item in tree._blocks.nonNulls) {
      item.accept(this, output);
      output.write(' ');
    }

    return output;
  }

  @override
  StringSink visitControlExpression(ControlExpression expression,
      [StringSink? output]) {
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
          'separator');
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
}
