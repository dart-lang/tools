// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

import 'errors.dart';
import 'pubspec.dart';

/// If [sourceUrl] is passed, it's used as the URL from which the YAML
/// originated for error reporting. It can be a [String], a [Uri], or `null`.
Pubspec parsePubspec(String yaml, {sourceUrl}) {
  var item = loadYaml(yaml, sourceUrl: sourceUrl);

  if (item == null) {
    throw new ArgumentError.notNull('yaml');
  }

  if (item is! YamlMap) {
    if (item is YamlNode) {
      throw parsedYamlException('Does not represent a YAML map.', item);
    }

    throw new ArgumentError.value(
        yaml, 'yaml', 'Does not represent a YAML map.');
  }

  try {
    return new Pubspec.fromJson(item as YamlMap);
  } on CheckedFromJsonException catch (error, stack) {
    throw parsedYamlExceptionFromError(error, stack);
  }
}
