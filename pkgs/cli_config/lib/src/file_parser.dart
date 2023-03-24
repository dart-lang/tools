// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

class FileParser {
  Map<String, dynamic> parse(
    String fileContents, {
    Uri? sourceUrl,
  }) {
    final parsedYaml = loadYaml(
      fileContents,
      sourceUrl: sourceUrl,
    );
    if (parsedYaml is! Map) {
      throw FormatException('YAML config must be set of key value pairs.');
    }
    return parseMap(parsedYaml);
  }

  Map<String, Object> parseMap(Map<dynamic, dynamic> input) => {
        for (final entry in input.entries)
          parseKey(entry.key as String): parseValue(entry.value as Object),
      };

  Object parseValue(Object value) {
    if (value is Map) {
      return parseMap(value);
    }
    return value;
  }

  String parseKey(String key) {
    final regex = RegExp('([a-z-_]+)');
    final match = regex.matchAsPrefix(key);
    if (match == null || match.group(0) != key) {
      throw FormatException(
          "Define '$key' does not match expected pattern '${regex.pattern}'.");
    }
    return key.replaceAll('-', '_');
  }
}
