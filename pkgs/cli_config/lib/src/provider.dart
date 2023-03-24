// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

abstract class Provider {
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

  /// Lookup an optional path in this config.
  ///
  /// If [resolveUri], resolves the paths in config file relative to the
  /// config file.
  Uri? getOptionalPath(
    String key, {
    bool resolveUri = true,
  });

  /// Lookup a list of paths in this config.
  ///
  /// If provided, [splitPattern] splits value.
  ///
  /// If [resolveUri], resolves the paths in config file relative to the
  /// config file.
  List<Uri>? getOptionalPathList(
    String key, {
    String? splitPattern,
    bool resolveUri = true,
  });

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
