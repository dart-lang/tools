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

final _skippedCases = [
  '2SXE_0',
  '3GZX_0',
  '4ABK_0',
  '4FJ6_0',
  '5KJE_0',
  '5WE3_0',
  '6KGN_0',
  '6M2F_0',
  '7BUB_0',
  '7W2P_0',
  '87E4_0',
  '8KB6_0',
  '8UDB_0',
  '9BXH_0',
  '9MMW_0',
  'A2M4_0',
  'C4HZ_0',
  'CFD4_0',
  'CN3R_0',
  'CT4Q_0',
  'CUP7_0',
  'DFF7_0',
  'E76Z_0',
  'FH7J_0',
  'FRK4_0',
  'GH63_0',
  'HMQ5_0',
  'JQ4R_0',
  'JS2J_0',
  'JTV5_0',
  'KK5P_0',
  'L94M_0',
  'L9U5_0',
  'LE5A_0',
  'LQZ7_0',
  'M2N8_0',
  'M2N8_1',
  'M5DY_0',
  'PW8X_0',
  'QF4Y_0',
  'RLU9_0',
  'RR7F_0',
  'RZP5_0',
  'S3PD_0',
  'S9E8_0',
  'UDR7_0',
  'UKK6_0',
  'UKK6_1',
  'V55R_0',
  'V9D5_0',
  'W42U_0',
  'W5VH_0',
  'WZ62_0',
  'X8DW_0',
  'XW4D_0',
  'ZWK4_0',
  'SYW4_0',
];

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
