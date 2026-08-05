// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'api_type.dart';

/// Parses a JSON list of objects using [fromJson].
List<T> parseList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) =>
    (json[key] as List<dynamic>?)
        ?.map((e) => fromJson(e as Map<String, dynamic>))
        .toList() ??
    [];

/// Parses a JSON list of strings.
List<String> parseStringList(Map<String, dynamic> json, String key) =>
    (json[key] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

/// Parses a JSON map representing type parameters and their bounds.
Map<String, ApiType?> parseTypeParameters(
  Map<String, dynamic> json,
  String key,
) {
  final map = json[key];
  if (map is! Map) return {};
  return {
    for (final entry in map.entries)
      entry.key as String: entry.value == null
          ? null
          : ApiType.fromJson(entry.value as Map<String, dynamic>),
  };
}
