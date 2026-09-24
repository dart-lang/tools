// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'fuzzer.dart';

final _skippedCases = <String>[];

Future<void> main() async {
  final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:yaml_edit/yaml_edit.dart'));

  final testdataUri =
      packageUri!.resolve('../../../third_party/yaml-test-suite/src/');
  final srcDir = Directory.fromUri(testdataUri);

  if (!srcDir.existsSync()) {
    print('yaml-test-suite src directory not found at ${srcDir.path}');
    return;
  }

  for (final file in srcDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.yaml')) continue;

    final content = file.readAsStringSync();

    final doc = loadYaml(content);
    if (doc is! YamlList) continue;

    for (final (i, testCase) in doc.indexed) {
      testCase as YamlMap;

      if (testCase.containsKey('error') || testCase.containsKey('fail')) {
        continue;
      }

      final yamlStr = testCase['yaml'];
      if (yamlStr is String) {
        final basename = file.uri.pathSegments.last.replaceAll('.yaml', '');
        final caseName = '${basename}_$i';

        if (_skippedCases.contains(caseName)) {
          test('yaml_test_suite_test.dart for $caseName', () {},
              skip: 'Known failures in "$caseName"');
          continue;
        }

        // Try parsing to verify it's valid yaml according to our parser
        try {
          withYamlWarningCallback(() {
            loadYamlNode(yamlStr);
          });
        } catch (_) {
          continue; // skip invalid YAML cases
        }
        final root = withYamlWarningCallback(() => YamlEditor(yamlStr));

        for (final (path, node) in allJsonPaths(root.parseAt([]))) {
          testJsonPath(caseName, yamlStr, path, node);
        }
      }
    }
  }
}
