// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';

/// Element categorization used by [MemberSortKey].
enum MemberCategory {
  constructor,
  propertyAccessor,
  topLevelFunctionOrMethod,
  interface,
  extension,
  typeAlias,
}

/// Sort key used to sort elements in the output.
final class MemberSortKey implements Comparable<MemberSortKey> {
  final bool isInstanceMember;
  final MemberCategory category;
  final String name;
  final bool isSetter;

  MemberSortKey({
    required this.isInstanceMember,
    required this.category,
    required this.name,
    required this.isSetter,
  });

  @override
  int compareTo(MemberSortKey other) {
    if ((isInstanceMember ? 1 : 0).compareTo(other.isInstanceMember ? 1 : 0)
        case final value when value != 0) {
      return value;
    }
    if (category.index.compareTo(other.category.index) case final value
        when value != 0) {
      return value;
    }
    if (category == MemberCategory.constructor &&
        other.category == MemberCategory.constructor) {
      if (name == 'new') {
        return other.name == 'new' ? 0 : -1;
      } else if (other.name == 'new') {
        return 1;
      }
    }
    if (name.compareTo(other.name) case final value when value != 0) {
      return value;
    }
    return (isSetter ? 1 : 0).compareTo(other.isSetter ? 1 : 0);
  }

  static MemberCategory computeCategory(Element element) => switch (element) {
    ConstructorElement() => MemberCategory.constructor,
    PropertyAccessorElement() => MemberCategory.propertyAccessor,
    TopLevelFunctionElement() => MemberCategory.topLevelFunctionOrMethod,
    MethodElement() => MemberCategory.topLevelFunctionOrMethod,
    InterfaceElement() => MemberCategory.interface,
    ExtensionElement() => MemberCategory.extension,
    TypeAliasElement() => MemberCategory.typeAlias,
    dynamic(:final runtimeType) => throw UnimplementedError(
      'Unexpected element: $runtimeType',
    ),
  };

  static bool computeIsInstanceMember(Element element) =>
      element.enclosingElement is InstanceElement &&
      switch (element) {
        ExecutableElement(:final isStatic) => !isStatic,
        dynamic(:final runtimeType) => throw UnimplementedError(
          'Unexpected element: $runtimeType',
        ),
      };
}
