// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Valid YAML', () {
    var rootValidDir = Directory('test/valid_yaml');
    if (!rootValidDir.existsSync()) {
      rootValidDir = Directory('valid_yaml');
    }
    if (!rootValidDir.existsSync()) throw StateError("valid_yaml directory not found");
    for (var file in rootValidDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.yaml')) continue;
        test(file.path, () {
          var content = file.readAsStringSync();
          expect(() => loadYaml(content), returnsNormally);
        });
    }
  });

  group('Invalid YAML', () {
    var rootInvalidDir = Directory('test/invalid_yaml');
    if (!rootInvalidDir.existsSync()) {
      rootInvalidDir = Directory('invalid_yaml');
    }
    if (!rootInvalidDir.existsSync()) throw StateError("invalid_yaml directory not found");
    for (var file in rootInvalidDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.yaml')) continue;
        test(file.path, () {
          var content = file.readAsStringSync();
          // Also handle cases where loadYaml strictly fails on validation logic!
          // We wrap it in a custom check in case loadYaml parses it but fails
          Object? err;
          try {
             loadYaml(content);
          } catch(e) {
             err = e;
          }
          expect(err, isNotNull, reason: 'Expected a YamlException to be thrown');
        });
    }
  });
}
