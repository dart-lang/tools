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

  /// If provided, used to resolve paths within [_cli].
  ///
  /// Typically the current working directory at application start.
  @override
  final Uri? baseUri;

  CliSource(this._cli, this.baseUri);

  @override
  String? optionalString(String key) {
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
  List<String>? optionalStringList(
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
  bool? optionalBool(String key) {
    final stringValue = optionalString(key);
    if (stringValue != null) {
      Source.throwIfUnexpectedValue(key, stringValue, Config.boolStrings.keys);
      return Config.boolStrings[stringValue]!;
    }
    return null;
  }

  @override
  int? optionalInt(String key) {
    final stringValue = optionalString(key);
    if (stringValue != null) {
      try {
        return int.parse(stringValue);
      } on FormatException catch (e) {
        throw FormatException(
            "Unexpected value '$stringValue' for key '$key'. Expected an int."
            ' ${e.message}');
      }
    }
    return null;
  }

  @override
  double? optionalDouble(String key) {
    final stringValue = optionalString(key);
    if (stringValue != null) {
      try {
        return double.parse(stringValue);
      } on FormatException catch (e) {
        throw FormatException(
            "Unexpected value '$stringValue' for key '$key'. Expected a double."
            ' ${e.message}');
      }
    }
    return null;
  }

  @override
  String toString() => 'CliSource($_cli)';
}
