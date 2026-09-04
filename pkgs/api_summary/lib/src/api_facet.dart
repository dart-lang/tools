// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'meta_facet.dart';

/// Base interface for domain-specific, contractual, or runtime facets attached
/// to an API declaration or library.
abstract interface class ApiFacet implements Comparable<ApiFacet> {
  /// The namespace identifying the facet kind (e.g. `'meta'`, `'js'`, `'ffi'`).
  String get namespace;

  /// Text representation for human-readable parentheticals in `api.txt`.
  List<String> get parentheticalSegments;

  /// JSON serialization for `api.json`.
  Map<String, dynamic> toJson();

  /// Deserializes an [ApiFacet] from a JSON map containing a `'namespace'`
  /// field.
  static ApiFacet fromJson(Map<String, dynamic> json) {
    final namespace = json['namespace'] as String?;
    return switch (namespace) {
      'meta' => MetaContractFacet.fromJson(json),
      _ => throw FormatException('Unknown ApiFacet namespace: "$namespace"'),
    };
  }
}
