// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Domain models for JavaScript interop annotations extracted from
/// `dart:js_interop` and `package:js`.
library;

import 'package:analyzer/dart/element/element.dart';

import 'api_trait.dart';

/// An [ApiTrait] capturing a `@JS([name])` annotation from `dart:js_interop`
/// or `package:js`.
final class JsBindingTrait implements ApiTrait {
  @override
  String get namespace => 'js';

  /// The customized JavaScript symbol name, if provided.
  final String? name;

  const JsBindingTrait([this.name]);

  /// Extracts a `@JS([name])` annotation from [element], or returns `null`
  /// if not present.
  static JsBindingTrait? fromElement(Element element) {
    for (final metadata in _metadataFor(element)) {
      for (final annotation in metadata.annotations) {
        final constant = annotation.computeConstantValue();
        if (constant == null) continue;
        final type = constant.type;
        if (type == null) continue;
        final typeElement = type.element;
        if (typeElement is! InterfaceElement) continue;
        final uri = typeElement.library.uri.toString();
        if (typeElement.name == 'JS' &&
            (uri == 'dart:js_interop' || uri == 'package:js/js.dart')) {
          final name = constant.getField('name')?.toStringValue();
          return JsBindingTrait(name);
        }
      }
    }
    return null;
  }

  factory JsBindingTrait.fromJson(Map<String, dynamic> json) =>
      JsBindingTrait(json['name'] as String?);

  @override
  Map<String, dynamic> toJson() => {
    'namespace': namespace,
    if (name != null) 'name': name,
  };

  @override
  List<String> get parentheticalSegments => [
    if (name != null) 'js: "$name"' else 'js',
  ];

  @override
  int compareTo(ApiTrait other) {
    final diff = namespace.compareTo(other.namespace);
    if (diff != 0) return diff;
    if (other is JsBindingTrait) {
      return (name ?? '').compareTo(other.name ?? '');
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsBindingTrait && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);
}

/// An [ApiTrait] capturing a `@JSExport([name])` annotation from
/// `dart:js_interop`.
final class JsExportTrait implements ApiTrait {
  @override
  String get namespace => 'js_export';

  /// The customized exported property name, if provided.
  final String? name;

  const JsExportTrait([this.name]);

  /// Extracts a `@JSExport([name])` annotation from [element], or returns
  /// `null` if not present.
  static JsExportTrait? fromElement(Element element) {
    for (final metadata in _metadataFor(element)) {
      for (final annotation in metadata.annotations) {
        final constant = annotation.computeConstantValue();
        if (constant == null) continue;
        final type = constant.type;
        if (type == null) continue;
        final typeElement = type.element;
        if (typeElement is! InterfaceElement) continue;
        final uri = typeElement.library.uri.toString();
        if (typeElement.name == 'JSExport' &&
            (uri == 'dart:js_interop' || uri.contains('interop'))) {
          final name = constant.getField('name')?.toStringValue();
          return JsExportTrait(name);
        }
      }
    }
    return null;
  }

  factory JsExportTrait.fromJson(Map<String, dynamic> json) =>
      JsExportTrait(json['name'] as String?);

  @override
  Map<String, dynamic> toJson() => {
    'namespace': namespace,
    if (name != null) 'name': name,
  };

  @override
  List<String> get parentheticalSegments => [
    if (name != null) 'jsExport: "$name"' else 'jsExport',
  ];

  @override
  int compareTo(ApiTrait other) {
    final diff = namespace.compareTo(other.namespace);
    if (diff != 0) return diff;
    if (other is JsExportTrait) {
      return (name ?? '').compareTo(other.name ?? '');
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsExportTrait && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);
}

Iterable<Metadata> _metadataFor(Element element) sync* {
  yield element.nonSynthetic.metadata;
  if (element is PropertyAccessorElement) {
    yield element.variable.nonSynthetic.metadata;
  }
}
