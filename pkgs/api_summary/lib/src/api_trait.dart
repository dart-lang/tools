// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'js_trait.dart';
import 'meta_trait.dart';

/// Base interface for domain-specific, contractual, or runtime traits attached
/// to an API declaration or library.
abstract interface class ApiTrait implements Comparable<ApiTrait> {
  /// The namespace identifying the trait kind (e.g. `'meta'`, `'js'`, `'ffi'`).
  String get namespace;

  /// Text representation for human-readable parentheticals in `api.txt`.
  List<String> get parentheticalSegments;

  /// JSON serialization for `api.json`.
  Map<String, dynamic> toJson();

  /// Deserializes an [ApiTrait] from a JSON map containing a `'namespace'`
  /// field.
  static ApiTrait fromJson(Map<String, dynamic> json) {
    final namespace = json['namespace'] as String?;
    return switch (namespace) {
      'meta' => MetaContractTrait.fromJson(json),
      'js' => JsBindingTrait.fromJson(json),
      'js_export' => JsExportTrait.fromJson(json),
      _ => throw FormatException('Unknown ApiTrait namespace: "$namespace"'),
    };
  }
}
