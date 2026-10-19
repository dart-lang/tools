// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Domain models for JavaScript interop annotations extracted from
/// `dart:js_interop` and `package:js`.
library;

import 'package:analyzer/dart/element/element.dart';

import 'api_facet.dart';

/// An [ApiFacet] capturing a `@JS([name])` annotation from `dart:js_interop`
/// or `package:js`.
final class JsBindingFacet implements ApiFacet {
  @override
  String get namespace => 'js';

  /// The customized JavaScript symbol name, if provided.
  final String? name;

  const JsBindingFacet([this.name]);

  /// Extracts a `@JS([name])` annotation from [element], or returns `null`
  /// if not present.
  static JsBindingFacet? fromElement(Element element) {
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
          return JsBindingFacet(name);
        }
      }
    }
    return null;
  }

  factory JsBindingFacet.fromJson(Map<String, dynamic> json) =>
      JsBindingFacet(json['name'] as String?);

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
  int compareTo(ApiFacet other) {
    final diff = namespace.compareTo(other.namespace);
    if (diff != 0) return diff;
    if (other is JsBindingFacet) {
      return (name ?? '').compareTo(other.name ?? '');
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsBindingFacet && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);
}

/// An [ApiFacet] capturing a `@JSExport([name])` annotation from
/// `dart:js_interop`.
final class JsExportFacet implements ApiFacet {
  @override
  String get namespace => 'js_export';

  /// The customized exported property name, if provided.
  final String? name;

  const JsExportFacet([this.name]);

  /// Extracts a `@JSExport([name])` annotation from [element], or returns
  /// `null` if not present.
  static JsExportFacet? fromElement(Element element) {
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
          return JsExportFacet(name);
        }
      }
    }
    return null;
  }

  factory JsExportFacet.fromJson(Map<String, dynamic> json) =>
      JsExportFacet(json['name'] as String?);

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
  int compareTo(ApiFacet other) {
    final diff = namespace.compareTo(other.namespace);
    if (diff != 0) return diff;
    if (other is JsExportFacet) {
      return (name ?? '').compareTo(other.name ?? '');
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsExportFacet && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);
}

Iterable<Metadata> _metadataFor(Element element) sync* {
  yield element.nonSynthetic.metadata;
  if (element is PropertyAccessorElement) {
    yield element.variable.nonSynthetic.metadata;
  }
}
