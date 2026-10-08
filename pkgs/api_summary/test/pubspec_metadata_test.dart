// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:api_summary/api_summary.dart';
import 'package:path/path.dart' as p;
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

    test('resolves relative packagePath (such as ".")', () async {
      await withTempPkg('name: relative_pkg\n', (pkgPath) async {
        final previousCurrent = Directory.current;
        try {
          Directory.current = pkgPath;
          final summary = await apiSummary('.');
          expect(summary.name, equals('relative_pkg'));
        } finally {
          Directory.current = previousCurrent;
        }
        final relativeFromCwd = p.relative(pkgPath);
        final summaryFromRelative = await apiSummary(relativeFromCwd);
        expect(summaryFromRelative.name, equals('relative_pkg'));
      });
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

    test(
      'throws FormatException when environment constraint is not a scalar',
      () async {
        await withTempPkg(
          '''
name: foo
environment:
  sdk: [3, 0]
''',
          (pkgPath) async {
            await expectLater(
              apiSummary(pkgPath),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Expected environment constraint for "sdk" '
                    'to be a string or scalar',
                  ),
                ),
              ),
            );
          },
        );

        await withTempPkg(
          '''
name: foo
environment:
  sdk:
    major: 3
''',
          (pkgPath) async {
            await expectLater(
              apiSummary(pkgPath),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Expected environment constraint for "sdk" '
                    'to be a string or scalar',
                  ),
                ),
              ),
            );
          },
        );
      },
    );

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

    test(
      'extracts dependencies and ignores dev_dependencies and overrides',
      () async {
        await withTempPkg(
          '''
name: sample_pkg
environment:
  sdk: ^3.12.0
dependencies:
  z_pkg: ^2.0.0
  a_pkg: ">=1.0.0 <2.0.0"
  range_pkg: ">= 13.0.0   < 15.0.0"
  any_pkg:
  flutter:
    sdk: flutter
  local_pkg:
    path: ../local_pkg
  hosted_pkg:
    hosted: https://pub.example.org
    version: ">=1.2.3 <2.0.0"
  git_pkg:
    git:
      url: https://example.com/git_pkg.git
      ref: main
dev_dependencies:
  test: ^1.28.0
dependency_overrides:
  a_pkg: ^1.5.0
''',
          (pkgPath) async {
            final summary = await apiSummary(pkgPath);
            expect(
              summary.dependencies.keys.toList(),
              equals([
                'a_pkg',
                'any_pkg',
                'flutter',
                'git_pkg',
                'hosted_pkg',
                'local_pkg',
                'range_pkg',
                'z_pkg',
              ]),
            );
            expect(
              summary.dependencies,
              equals({
                'a_pkg': '^1.0.0',
                'any_pkg': 'any',
                'flutter': '{sdk: flutter}',
                'git_pkg':
                    '{git: {ref: main, url: https://example.com/git_pkg.git}}',
                'hosted_pkg':
                    '{hosted: https://pub.example.org, version: ^1.2.3}',
                'local_pkg': '{path: ../local_pkg}',
                'range_pkg': '>=13.0.0 <15.0.0',
                'z_pkg': '^2.0.0',
              }),
            );
            expect(summary.dependencies.containsKey('test'), isFalse);

            final json = summary.toJson();
            expect(json['dependencies'], equals(summary.dependencies));
            final rehydrated = ApiSummary.fromJson(json);
            expect(rehydrated.dependencies, equals(summary.dependencies));
            expect(
              summary.toString(),
              contains(
                'dependencies:\n'
                '  a_pkg: ^1.0.0\n'
                '  any_pkg: any\n'
                '  flutter: {sdk: flutter}\n'
                '  git_pkg: '
                '{git: {ref: main, url: https://example.com/git_pkg.git}}\n'
                '  hosted_pkg: '
                '{hosted: https://pub.example.org, version: ^1.2.3}\n'
                '  local_pkg: {path: ../local_pkg}\n'
                '  range_pkg: >=13.0.0 <15.0.0\n'
                '  z_pkg: ^2.0.0\n',
              ),
            );
          },
        );
      },
    );

    test('normalizes equivalent version constraints in environment '
        'and dependencies', () async {
      await withTempPkg(
        '''
name: sample_pkg
environment:
  sdk: ">=3.12.0 <4.0.0"
dependencies:
  foo: ">= 1.2.3   < 2.0.0"
''',
        (pkgPath) async {
          final summary = await apiSummary(pkgPath);
          expect(summary.environment, equals({'sdk': '^3.12.0'}));
          expect(summary.dependencies, equals({'foo': '^1.2.3'}));
        },
      );
    });

    test('throws FormatException when dependencies is not a map', () async {
      await withTempPkg('name: foo\ndependencies: "^1.0.0"', (pkgPath) async {
        await expectLater(
          apiSummary(pkgPath),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Expected "dependencies" to be a YAML map'),
            ),
          ),
        );
      });
    });

    test(
      'throws FormatException when dependency constraint is invalid',
      () async {
        await withTempPkg(
          '''
name: foo
dependencies:
  bar: [1, 2]
''',
          (pkgPath) async {
            await expectLater(
              apiSummary(pkgPath),
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Expected dependency constraint for "bar" '
                    'to be a string, null, or map',
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
