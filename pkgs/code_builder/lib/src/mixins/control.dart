// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../specs/control.dart';

@internal
@immutable
@BuiltValue(instantiable: false)
abstract mixin class ControlBody {
  /// The body of this block.
  ///
  /// *Note: will always be wrapped in `{`braces`}`*.
  Code? get body;
}

@internal
abstract mixin class ControlBodyBuilder {
  /// The body of this block.
  Code? body;

  /// Appends [code] to [body].
  void addCode(Code code) {
    body = Block((block) {
      block.statements.addAll(switch (body) {
        null => [],
        final Block body => body.statements,
        final Code code => [code],
      });

      block.statements.add(code);
    });
  }

  /// Appends [expression] to [body] as a statement.
  void addExpression(Expression expression) => addCode(expression.statement);
}

@internal
@immutable
@BuiltValue(instantiable: false)
abstract mixin class ControlLabel implements ControlBody {
  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  String? get label;
}

@internal
abstract mixin class ControlLabelBuilder implements ControlBodyBuilder {
  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  String? label;
}
