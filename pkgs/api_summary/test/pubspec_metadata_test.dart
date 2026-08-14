// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:api_summary/api_summary.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
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

  group('pubspec.yaml parsing in apiSummary', () {
    Future<void> withTempPkg(
      String pubspecContent,
      Future<void> Function(String pkgPath) fn,
    ) async {
      await d.dir('pkg', [
        d.file('pubspec.yaml', pubspecContent),
        d.dir('lib', [d.file('foo.dart', 'void foo() {}')]),
      ]).create();

      await fn(d.path('pkg'));
    }

    test('extracts environment and executables successfully', () async {
      await withTempPkg(
        '''
name: sample_pkg
environment:
  sdk: ^3.12.0
  flutter: ">=3.2.0 <3.9.0"
executables:
  tool_a:
  tool_b: custom_b
''',
        (pkgPath) async {
          final summary = await apiSummary(pkgPath);
          expect(summary.name, equals('sample_pkg'));
          expect(
            summary.environment,
            equals({'flutter': '>=3.2.0 <3.9.0', 'sdk': '^3.12.0'}),
          );
          expect(
            summary.executables,
            equals({'tool_a': null, 'tool_b': 'custom_b'}),
          );
        },
      );
    });

    test('handles omitted and null environment and executables', () async {
      await withTempPkg(
        '''
name: minimal_pkg
environment:
executables:
''',
        (pkgPath) async {
          final summary = await apiSummary(pkgPath);
          expect(summary.name, equals('minimal_pkg'));
          expect(summary.environment, isEmpty);
          expect(summary.executables, isEmpty);
        },
      );
    });

    test('ignores null environment constraints', () async {
      await withTempPkg(
        '''
name: sample_pkg
environment:
  sdk: ^3.12.0
  flutter:
''',
        (pkgPath) async {
          final summary = await apiSummary(pkgPath);
          expect(summary.environment, equals({'sdk': '^3.12.0'}));
        },
      );
    });

    test('throws FormatException when pubspec is not a YAML map', () async {
      await withTempPkg('- item1\n- item2', (pkgPath) async {
        await expectLater(
          apiSummary(pkgPath),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Expected pubspec to be a YAML map'),
            ),
          ),
        );
      });
    });

    test(
      'throws FormatException when name is missing or not a string',
      () async {
        await withTempPkg(
          '''
environment:
  sdk: ^3.12.0
''',
          (pkgPath) async {
            await expectLater(
              apiSummary(pkgPath),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains('Expected pubspec to contain a "name" string'),
                ),
              ),
            );
          },
        );

        await withTempPkg('name: 12345', (pkgPath) async {
          await expectLater(
            apiSummary(pkgPath),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('Expected pubspec to contain a "name" string'),
              ),
            ),
          );
        });
      },
    );

    test('throws FormatException when environment is not a map', () async {
      await withTempPkg('name: foo\nenvironment: "sdk ^3.12.0"', (
        pkgPath,
      ) async {
        await expectLater(
          apiSummary(pkgPath),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Expected "environment" to be a YAML map'),
            ),
          ),
        );
      });
    });

    test('throws FormatException when executables is not a map', () async {
      await withTempPkg('name: foo\nexecutables: "my_tool"', (pkgPath) async {
        await expectLater(
          apiSummary(pkgPath),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Expected "executables" to be a YAML map'),
            ),
          ),
        );
      });
    });

    test(
      'throws FormatException when executable target is not string or null',
      () async {
        await withTempPkg(
          '''
name: foo
executables:
  my_tool: [invalid, target]
''',
          (pkgPath) async {
            await expectLater(
              apiSummary(pkgPath),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Expected executable target for "my_tool" '
                    'to be a string or null',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  });
}
