import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Valid YAML', () {
    var validDir = Directory('valid_yaml'); // run from 'test/' or package root
    // we use relative paths safely
    var rootValidDir = Directory('test/valid_yaml');
    if (rootValidDir.existsSync()) {
      for (var file in rootValidDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.yaml')) continue;
        test(file.path, () {
          var content = file.readAsStringSync();
          expect(() => loadYaml(content), returnsNormally);
        });
      }
    }
  });

  group('Invalid YAML', () {
    var rootInvalidDir = Directory('test/invalid_yaml');
    if (rootInvalidDir.existsSync()) {
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
    }
  });
}
