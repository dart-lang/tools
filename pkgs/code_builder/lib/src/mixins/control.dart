// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

part of '../specs/control.dart';

/// Root class for control-flow blocks.
///
/// {@category controlFlow}
@internal
@immutable
abstract mixin class ControlBlock implements Code, Spec {
  /// The full control-flow expression that precedes this block.
  ControlExpression get _expression;

  /// The body of this block.
  ///
  /// *Note: will always be wrapped in `{`braces`}`*.
  Block get body;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlBlock(this, context);
}

/// Adds label support to a [ControlBlock].
///
/// {@category controlFlow}
@internal
@immutable
mixin LabeledControlBlock on ControlBlock {
  /// An (optional) label for this block.
  ///
  /// ```dart
  /// label: {block}
  /// ```
  ///
  /// https://dart.dev/language/loops#labels
  String? get label;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitLabeledBlock(this);
}

/// A tree of [ControlBlock]s
///
/// {@category controlFlow}
@internal
@immutable
abstract mixin class ControlTree implements Code, Spec {
  /// The items in this tree.
  List<ControlBlock?> get _blocks;

  @override
  R accept<R>(covariant ControlBlockVisitor<R> visitor, [R? context]) =>
      visitor.visitControlTree(this, context);
}
