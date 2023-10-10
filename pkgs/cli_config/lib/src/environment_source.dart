// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'config.dart';
import 'source.dart';

class EnvironmentSource extends Source {
  /// Configuration options passed in via the [Platform.environment].
  ///
  /// The keys have been transformed by `EnvironmentParser.parseKey`.
  ///
  /// Environment values are left intact.
  ///
  /// Stored as a flat non-hierarchical structure, keys contain `.`.
  final Map<String, String> _environment;

  EnvironmentSource(this._environment);

  @override
  String? optionalString(String key) => _environment[key];

  @override
  List<String>? optionalStringList(
    String key, {
    String? splitPattern,
  }) {
    final envValue = _environment[key];
    if (envValue == null) {
      return null;
    }
    if (splitPattern != null) {
      return envValue.split(splitPattern);
    }
    return [envValue];
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
  String toString() => 'EnvironmentSource($_environment)';

  /// Environment path are not resolved.
  @override
  Uri? get baseUri => null;
}
