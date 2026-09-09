// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:meta/meta.dart';

import '../base.dart';
import '../mixins/annotations.dart';
import '../mixins/dartdoc.dart';
import '../mixins/generics.dart';
import '../visitors.dart';
import 'expression.dart';
import 'field.dart';
import 'method.dart';
import 'reference.dart';

part 'mixin.g.dart';

@immutable
abstract class Mixin extends Object
    with HasAnnotations, HasDartDocs, HasGenerics
    implements Built<Mixin, MixinBuilder>, Spec {
  factory Mixin([void Function(MixinBuilder b) updates]) = _$Mixin;

  Mixin._();

  /// Whether the mixin is a `base mixin`.
  bool get base;

  @override
  BuiltList<Expression> get annotations;

  @override
  BuiltList<String> get docs;

  /// A single superclass constraint for this mixin.
  ///
  /// For a mixin with more than one superclass constraint, use [onTypes]
  /// instead, which takes precedence over this field when non-empty.
  Reference? get on;

  /// The superclass constraints for this mixin, e.g. `on A, B, C`.
  ///
  /// Takes precedence over [on] when non-empty.
  BuiltList<Reference> get onTypes;

  BuiltList<Reference> get implements;

  @override
  BuiltList<Reference> get types;

  BuiltList<Method> get methods;
  BuiltList<Field> get fields;

  /// Name of the mixin.
  String get name;

  @override
  R accept<R>(SpecVisitor<R> visitor, [R? context]) =>
      visitor.visitMixin(this, context);
}

abstract class MixinBuilder extends Object
    with HasAnnotationsBuilder, HasDartDocsBuilder, HasGenericsBuilder
    implements Builder<Mixin, MixinBuilder> {
  factory MixinBuilder() = _$MixinBuilder;

  MixinBuilder._();

  /// Whether the mixin is a `base mixin`.
  bool base = false;

  @override
  ListBuilder<Expression> annotations = ListBuilder<Expression>();

  @override
  ListBuilder<String> docs = ListBuilder<String>();

  /// A single superclass constraint for this mixin.
  ///
  /// For a mixin with more than one superclass constraint, use [onTypes]
  /// instead, which takes precedence over this field when non-empty.
  Reference? on;

  /// The superclass constraints for this mixin, e.g. `on A, B, C`.
  ///
  /// Takes precedence over [on] when non-empty.
  ListBuilder<Reference> onTypes = ListBuilder<Reference>();

  ListBuilder<Reference> implements = ListBuilder<Reference>();

  @override
  ListBuilder<Reference> types = ListBuilder<Reference>();

  ListBuilder<Method> methods = ListBuilder<Method>();

  ListBuilder<Field> fields = ListBuilder<Field>();

  /// Name of the mixin.
  String? name;
}
