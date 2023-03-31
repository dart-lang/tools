// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

abstract class Source {
  /// If provided, the uri used for resolving paths.
  Uri? get baseUri;

  /// Lookup a nullable string value.
  String? optionalString(String key);

  /// Lookup a nullable string list.
  ///
  /// If provided, [splitPattern] splits config.
  List<String>? optionalStringList(
    String key, {
    String? splitPattern,
  });

  /// Lookup an optional boolean value.
  bool? optionalBool(String key);

  /// Lookup an optional int value.
  int? optionalInt(String key);

  /// Lookup an optional int value.
  double? optionalDouble(String key);

  /// Lookup an optional value of type [T].
  ///
  /// Does not support specialized options such as `splitPattern`. One must
  /// use the specialized methods such as [optionalStringList] for that.
  ///
  /// Returns `null` if the source cannot provide a value of type [T].
  T? optionalValueOf<T>(String key) {
    if (T == bool) {
      return optionalBool(key) as T?;
    }
    if (T == String) {
      return optionalString(key) as T?;
    }
    if (T == List<String>) {
      return optionalStringList(key) as T?;
    }
    return null;
  }

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
