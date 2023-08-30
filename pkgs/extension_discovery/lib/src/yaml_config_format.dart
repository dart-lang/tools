// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utilities for loading and validating YAML from a config file.
///
/// When writing YAML config files it's often preferable to force a few
/// constraints on the YAML files. Specifically:
///  * Root value must be a map.
///  * No anchors / aliases, this can't be represented in JSON and
///    can be used to created cycles, which might crash someone trying to
///    serialize the data as JSON.
///  * Maps can only have string keys.
///
/// Basically, only allow value that can't be represented in JSON.
///
/// This library aims to provide a [parseYamlFromConfigFile] that throws
/// a [FormatException] when parsing YAML files that doesn't satisfy this
/// constraint.
library;

import 'package:yaml/yaml.dart'
    show YamlList, YamlMap, YamlNode, YamlScalar, loadYamlNode;

/// Parse YAML from a config file.
///
/// This will validate that:
///  * Maps only have string keys.
///  * Anchor and aliases are not used (to avoid cycles).
///  * Values can be represented as JSON.
///  * Root node is a map.
///
/// Throw will throw [FormatException], if the [yamlString] does not satisfy
/// constraints above.
///
/// Returns a structure consisting of the following types:
///  * `null`,
///  * [bool] (`true` or `false`),
///  * [String],
///  * [num] ([int] or [double]),
///  * [List<Object?>], and,
///  * [Map<String, Object?>].
Map<String, Object?> parseYamlFromConfigFile(String yamlString) {
  final visited = <YamlNode>{};
  Object? toPlainType(YamlNode n) {
    if (!visited.add(n)) {
      throw FormatException(
        'Anchors/aliases are not supported in YAML config files',
      );
    }
    if (n is YamlScalar) {
      return switch (n.value) {
        null => null,
        String s => s,
        num n => n,
        bool b => b,
        _ => throw FormatException(
            'Only null, string, number, bool, map and lists are supported '
            'in YAML config files',
          ),
      };
    }
    if (n is YamlList) {
      return n.nodes.map(toPlainType).toList();
    }
    if (n is YamlMap) {
      return n.nodes.map((key, value) {
        final k = toPlainType(key as YamlNode);
        if (k is! String) {
          throw FormatException(
            'Only string keys are allowed in YAML config files',
          );
        }
        return MapEntry(k, toPlainType(value));
      });
    }
    throw UnsupportedError('Unknown YamlNode: $n');
  }

  final value = toPlainType(loadYamlNode(yamlString));
  if (value is! Map<String, Object?>) {
    throw FormatException('The root of a YAML config file must be a map');
  }
  return value;
}
