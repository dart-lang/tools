// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

abstract class Source {
  /// If provided, the uri used for resolving paths.
  Uri? get baseUri;

  /// Lookup a nullable string value.
  String? getOptionalString(String key);

  /// Lookup a nullable string list.
  ///
  /// If provided, [splitPattern] splits config.
  List<String>? getOptionalStringList(
    String key, {
    String? splitPattern,
  });

  /// Lookup an optional boolean value.
  bool? getOptionalBool(String key);

  static void throwIfUnexpectedValue<T>(
      String key, T value, Iterable<T> validValues) {
    if (!validValues.contains(value)) {
      throw FormatException(
          "Unexpected value '$value' for key '$key'. Expected one of: "
          "${validValues.map((e) => "'$e'").join(', ')}.");
    }
  }

  static Uri fileSystemPathToUri(String path) {
    if (path.endsWith(Platform.pathSeparator)) {
      return Uri.directory(path);
    }
    return Uri.file(path);
  }
}
