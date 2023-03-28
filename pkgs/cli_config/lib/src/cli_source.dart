// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'config.dart';
import 'source.dart';

class CliSource extends Source {
  /// Configuration options passed in via CLI arguments.
  ///
  /// Options can be passed multiple times, so the values here are a list.
  ///
  /// Stored as a flat non-hierarchical structure, keys contain `.`.
  final Map<String, List<String>> _cli;

  CliSource(this._cli);

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
      Source.throwIfUnexpectedValue(key, stringValue, Config.boolStrings.keys);
      return Config.boolStrings[stringValue]!;
    }
    return null;
  }

  @override
  String toString() => 'CliSource($_cli)';

  @override

  /// CLI paths are not resolved.
  Uri? get baseUri => null;
}
