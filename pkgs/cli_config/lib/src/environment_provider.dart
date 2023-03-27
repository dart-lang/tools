// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'config.dart';
import 'provider.dart';

class EnvironmentProvider extends Provider {
  /// Configuration options passed in via the [Platform.environment].
  ///
  /// The keys have been transformed by [EnvironmentParser.parseKey].
  ///
  /// Environment values are left intact.
  ///
  /// Stored as a flat non-hierarchical structure, keys contain `.`.
  final Map<String, String> _environment;

  EnvironmentProvider(this._environment);

  @override
  String? getOptionalString(String key) => _environment[key];

  @override
  List<String>? getOptionalStringList(
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
  String toString() => 'EnvironmentProvider($_environment)';

  /// Environment path are not resolved.
  @override
  Uri? get baseUri => null;
}
