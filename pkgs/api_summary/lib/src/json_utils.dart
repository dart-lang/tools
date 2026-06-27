// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
