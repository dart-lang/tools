// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:api_summary/api_summary.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('ApiSummary environment and executables', () {
    test('sorts environment and executables keys alphabetically', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {
          'sdk': '^3.12.0',
          'flutter': '>=3.2.0 <3.9.0',
          'fuchsia': '>=1.0.0',
        },
        executables: {'z_tool': null, 'a_tool': 'main_a', 'm_tool': 'm_tool'},
        libraries: [],
      );

      expect(
        summary.environment.keys.toList(),
        equals(['flutter', 'fuchsia', 'sdk']),
      );
      expect(
        summary.executables.keys.toList(),
        equals(['a_tool', 'm_tool', 'z_tool']),
      );
    });

    test(
      'produces identical output regardless of input map insertion order',
      () {
        final summaryA = ApiSummary(
          name: 'test_pkg',
          environment: {'sdk': '^3.12.0', 'flutter': '>=3.2.0 <3.9.0'},
          executables: {'z_tool': null, 'a_tool': 'main_a'},
          libraries: [],
        );

        final summaryB = ApiSummary(
          name: 'test_pkg',
          environment: {'flutter': '>=3.2.0 <3.9.0', 'sdk': '^3.12.0'},
          executables: {'a_tool': 'main_a', 'z_tool': null},
          libraries: [],
        );

        expect(summaryA.toString(), equals(summaryB.toString()));
        expect(summaryA.toJson(), equals(summaryB.toJson()));
      },
    );

    test('toJson and fromJson round-trip with environment and executables', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {'sdk': '^3.12.0', 'flutter': '>=3.2.0 <3.9.0'},
        executables: {'cli_a': null, 'cli_b': 'custom_b'},
        libraries: [],
      );

      final json = summary.toJson();
      expect(json['name'], equals('test_pkg'));
      expect(
        json['environment'],
        equals({'flutter': '>=3.2.0 <3.9.0', 'sdk': '^3.12.0'}),
      );
      expect(json['executables'], equals({'cli_a': null, 'cli_b': 'custom_b'}));

      final rehydrated = ApiSummary.fromJson(json);
      expect(rehydrated.name, equals('test_pkg'));
      expect(rehydrated.environment, equals(summary.environment));
      expect(rehydrated.executables, equals(summary.executables));
    });

    test('toJson omits environment and executables when empty', () {
      final summary = ApiSummary(name: 'test_pkg', libraries: []);

      final json = summary.toJson();
      expect(json.containsKey('environment'), isFalse);
      expect(json.containsKey('executables'), isFalse);

      final rehydrated = ApiSummary.fromJson(json);
      expect(rehydrated.environment, isEmpty);
      expect(rehydrated.executables, isEmpty);
    });

    test('text rendering formats environment and executables', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {'sdk': '^3.12.0', 'flutter': '>=3.2.0 <3.9.0'},
        executables: {
          'simple_tool': null,
          'same_name_tool': 'same_name_tool',
          'custom_tool': 'custom_script',
        },
        libraries: [],
      );

      final rendered = summary.toString();
      expect(
        rendered,
        equals(
          'environment:\n'
          '  flutter: >=3.2.0 <3.9.0\n'
          '  sdk: ^3.12.0\n'
          'executables:\n'
          '  custom_tool: custom_script\n'
          '  same_name_tool\n'
          '  simple_tool\n',
        ),
      );
    });

    test('yaml serialization renders environment and executables', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {'sdk': '^3.12.0'},
        executables: {'my_tool': null},
        libraries: [],
      );

      final editor = YamlEditor('');
      editor.update([], summary.toJson());
      final yaml = '$editor\n';

      expect(yaml, contains('environment:\n  sdk: ^3.12.0'));
      expect(yaml, contains('executables:\n  my_tool: null'));
    });
  });
}
