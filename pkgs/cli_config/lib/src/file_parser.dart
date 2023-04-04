// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

class FileParser {
  Map<String, Object> parse(
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

  Map<K, Object> parseMap<K extends Object>(Map<dynamic, dynamic> input) {
    final result = <K, Object>{};
    for (final entry in input.entries) {
      final keyUnparsed = entry.key;
      final value = parseValue(entry.value as Object);
      if (keyUnparsed is String) {
        final key = parseKey(entry.key as String);
        result[key as K] = value;
      } else {
        result[keyUnparsed as K] = value;
      }
    }
    return result;
  }

  Object parseValue(Object value) {
    if (value is Map) {
      return parseMap(value);
    }
    return value;
  }

  static final _keyRegex = RegExp('([a-z-_]+)');

  String parseKey(String key) {
    final match = _keyRegex.matchAsPrefix(key);
    if (match == null || match.group(0) != key) {
      throw FormatException("Define '$key' does not match expected pattern "
          "'${_keyRegex.pattern}'.");
    }
    return key.replaceAll('-', '_');
  }
}
