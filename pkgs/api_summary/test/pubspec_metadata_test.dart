// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:api_summary/api_summary.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('canonicalizeConstraint', () {
    test('canonicalizes caret syntax', () {
      expect(canonicalizeConstraint('^1.2.3'), equals('^1.2.3'));
      expect(canonicalizeConstraint('^1.2.3-alpha'), equals('^1.2.3-alpha'));
      expect(canonicalizeConstraint('^0.1.2'), equals('^0.1.2'));
      expect(canonicalizeConstraint('^0.0.3'), equals('^0.0.3'));
    });

    test('canonicalizes compatible ranges to caret syntax', () {
      expect(canonicalizeConstraint('>=1.2.3 <2.0.0'), equals('^1.2.3'));
      expect(canonicalizeConstraint('>=1.2.3 <2.0.0-0'), equals('^1.2.3'));
      expect(canonicalizeConstraint('>=0.1.2 <0.2.0'), equals('^0.1.2'));
      expect(canonicalizeConstraint('>=0.0.3 <0.1.0'), equals('^0.0.3'));
      expect(canonicalizeConstraint('>=3.12.0 <4.0.0'), equals('^3.12.0'));
    });

    test('preserves non-caret compatible ranges and exact versions', () {
      expect(
        canonicalizeConstraint('>=3.0.0 <3.5.0'),
        equals('>=3.0.0 <3.5.0'),
      );
      expect(
        canonicalizeConstraint('>=0.0.3 <0.0.4'),
        equals('>=0.0.3 <0.0.4'),
      );
      expect(canonicalizeConstraint('>=3.0.0'), equals('>=3.0.0'));
      expect(
        canonicalizeConstraint('>1.0.0 <=2.0.0'),
        equals('>1.0.0 <=2.0.0'),
      );
      expect(canonicalizeConstraint('any'), equals('any'));
      expect(canonicalizeConstraint('1.2.3'), equals('1.2.3'));
    });

    test('throws ArgumentError on invalid constraint', () {
      expect(
        () => canonicalizeConstraint('invalid_version'),
        throwsArgumentError,
      );
      expect(() => canonicalizeConstraint('>=1.0.0 <'), throwsArgumentError);
    });
  });

  group('ApiSummary environment and executables', () {
    test('sorts environment and executables keys alphabetically', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {
          'sdk': '^3.12.0',
          'flutter': '^3.10.0',
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

    test('toJson and fromJson round-trip with environment and executables', () {
      final summary = ApiSummary(
        name: 'test_pkg',
        environment: {'sdk': '^3.12.0', 'flutter': '^3.10.0'},
        executables: {'cli_a': null, 'cli_b': 'custom_b'},
        libraries: [],
      );

      final json = summary.toJson();
      expect(json['name'], equals('test_pkg'));
      expect(
        json['environment'],
        equals({'flutter': '^3.10.0', 'sdk': '^3.12.0'}),
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
        environment: {'sdk': '^3.12.0', 'flutter': '^3.10.0'},
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
          '  flutter: ^3.10.0\n'
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
