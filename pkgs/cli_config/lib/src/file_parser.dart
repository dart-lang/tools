// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

class FileParser {
  Map<String, Object?> parse(
    String fileContents, {
    Uri? sourceUrl,
  }) {
    final parsedYaml = loadYaml(
      fileContents,
      sourceUrl: sourceUrl,
    );
    if (parsedYaml is! Map) {
      throw const FormatException(
          'YAML config must be set of key value pairs.');
    }
    return parseToplevelMap(parsedYaml);
  }

  Map<String, Object?> parseToplevelMap(Map<dynamic, dynamic> input) {
    final result = <String, Object?>{};
    for (final entry in input.entries) {
      final key = parseToplevelKey(entry.key);
      final value = entry.value as Object?;
      result[key] = value;
    }
    return result;
  }

  static final _keyRegex = RegExp('([a-z-_]+)');

  String parseToplevelKey(Object? key) {
    if (key is! String) {
      throw FormatException("Key '$key' is not a String.");
    }
    final match = _keyRegex.matchAsPrefix(key);
    if (match == null || match.group(0) != key) {
      throw FormatException("Define '$key' does not match expected pattern "
          "'${_keyRegex.pattern}'.");
    }
    return key.replaceAll('-', '_');
  }
}
