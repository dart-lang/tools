// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'config.dart';
import 'provider.dart';

class CliProvider extends Provider {
  /// Configuration options passed in via CLI arguments.
  ///
  /// Options can be passed multiple times, so the values here are a list.
  ///
  /// Stored as a flat non-hierarchical structure, keys contain `.`.
  final Map<String, List<String>> _cli;

  CliProvider(this._cli);

  @override
  String? getOptionalString(String key) {
    final value = _cli[key];
    if (value == null) {
      return null;
    }
    if (value.length > 1) {
      throw FormatException(
          "More than one value was passed for '$key' in the CLI defines."
          ' Values passed: $value');
    }
    return value.single;
  }

  @override
  List<String>? getOptionalStringList(
    String key, {
    String? splitPattern,
  }) {
    final cliValue = _cli[key];
    if (cliValue == null) {
      return null;
    }
    if (splitPattern != null) {
      return [for (final value in cliValue) ...value.split(splitPattern)];
    }
    return cliValue;
  }

  @override
  bool? getOptionalBool(String key) {
    final stringValue = getOptionalString(key);
    if (stringValue != null) {
      Provider.throwIfUnexpectedValue(
          key, stringValue, Config.boolStrings.keys);
      return Config.boolStrings[stringValue]!;
    }
    return null;
  }

  @override
  Uri? getOptionalPath(
    String key, {
    bool resolveUri = false,
  }) {
    assert(resolveUri == false);
    final stringValue = getOptionalString(key);
    if (stringValue != null) {
      return Provider.fileSystemPathToUri(stringValue);
    }
    return null;
  }

  @override
  List<Uri>? getOptionalPathList(
    String key, {
    String? splitPattern,
    bool resolveUri = false,
  }) {
    assert(resolveUri == false);
    final strings = getOptionalStringList(key, splitPattern: splitPattern);
    return strings?.map((e) => Uri(path: e)).toList();
  }

  @override
  String toString() => 'CliProvider($_cli)';
}
