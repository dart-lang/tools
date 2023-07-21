// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;

Map<String, Object?> decodeJsonMap(String json) {
  final root = jsonDecode(json);
  if (root case Map<String, Object?> v) return v;
  throw FormatException('root must be a map');
}

extension ExpectJson on Map<String, Object?> {
  bool expectBool(String key) {
    if (this[key] case bool v) return v;
    throw FormatException('"key" must be a bool');
  }

  num expectNumber(String key) {
    if (this[key] case num v) return v;
    throw FormatException('"key" must be a number');
  }

  String expectString(String key) {
    if (this[key] case String v) return v;
    throw FormatException('"key" must be a string');
  }

  Uri expectUri(String key) {
    try {
      return Uri.parse(expectString(key));
    } on FormatException {
      throw FormatException('"key" must be a URI');
    }
  }

  List<Object?> expectList(String key) {
    if (this[key] case List<Object?> v) return v;
    throw FormatException('"key" must be a list');
  }

  Iterable<Map<String, Object?>> expectListObjects(String key) sync* {
    final list = expectList(key);
    for (final entry in list) {
      if (entry case Map<String, Object?> v) {
        yield v;
      } else {
        throw FormatException('"key" must be a list of map');
      }
    }
  }
}