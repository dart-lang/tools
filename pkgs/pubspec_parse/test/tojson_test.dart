// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Pubspec toJson tests', () {
    test('minimal set values', () async {
      final value = await parse(defaultPubspec);
      final jsonValue = value.toJson();

      expect(jsonValue, {
        'name': 'sample',
        'version': null,
        'publish_to': null,
        'description': null,
        'homepage': null,
        'author': null,
        'authors': isA<List>(),
        'environment': {'sdk': '>=2.12.0 <3.0.0'},
        'documentation': null,
        'dependencies': isA<Map<String, dynamic>>(),
        'dev_dependencies': isA<Map<String, dynamic>>(),
        'dependency_overrides': isA<Map<String, dynamic>>(),
        'flutter': null,
        'repository': null,
        'issue_tracker': null,
        'screenshots': isA<List>(),
        'workspace': null,
        'resolution': null,
        'executables': isA<Map<String, dynamic>>(),
        'funding': null,
        'topics': null,
        'ignored_advisories': null,
      });
    });

    test('all fields set', () async {
      final version = Version.parse('1.2.3');
      final sdkConstraint = VersionConstraint.parse('>=3.6.0 <4.0.0');

      final value = await parse({
        'name': 'sample',
        'version': version.toString(),
        'publish_to': 'none',
        'author': 'name@example.com',
        'environment': {'sdk': sdkConstraint.toString()},
        'description': 'description',
        'homepage': 'homepage',
        'documentation': 'documentation',
        'repository': 'https://github.com/example/repo',
        'issue_tracker': 'https://github.com/example/repo/issues',
        'funding': ['https://patreon.com/example'],
        'topics': ['widget', 'button'],
        'ignored_advisories': ['111', '222'],
        'screenshots': [
          {'description': 'my screenshot', 'path': 'path/to/screenshot'},
        ],
        'workspace': ['pkg1', 'pkg2'],
        'resolution': 'workspace',
        'executables': {
          'my_script': 'bin/my_script.dart',
          'my_script2': 'bin/my_script2.dart',
        },
        'dependencies': {'foo': '1.0.0'},
        'dev_dependencies': {'bar': '2.0.0'},
        'dependency_overrides': {'baz': '3.0.0'},
      }, skipTryPub: true);

      final jsonValue = value.toJson();

      expect(jsonValue, {
        'name': 'sample',
        'version': version.toString(),
        'publish_to': 'none',
        'description': 'description',
        'homepage': 'homepage',
        'author': 'name@example.com',
        'authors': ['name@example.com'],
        'environment': {'sdk': sdkConstraint.toString()},
        'documentation': 'documentation',
        'dependencies': {
          'foo': {'version': '1.0.0'},
        },
        'dev_dependencies': {
          'bar': {'version': '2.0.0'},
        },
        'dependency_overrides': {
          'baz': {'version': '3.0.0'},
        },
        'flutter': null,
        'repository': 'https://github.com/example/repo',
        'issue_tracker': 'https://github.com/example/repo/issues',
        'screenshots': [
          {'description': 'my screenshot', 'path': 'path/to/screenshot'},
        ],
        'funding': ['https://patreon.com/example'],
        'topics': ['widget', 'button'],
        'ignored_advisories': ['111', '222'],
        'workspace': ['pkg1', 'pkg2'],
        'resolution': 'workspace',
        'executables': {
          'my_script': 'bin/my_script.dart',
          'my_script2': 'bin/my_script2.dart',
        },
      });
    });
  });

  group('Pubspec round trip tests', () {
    test('minimal set values', () async {
      final value = await parse(defaultPubspec);
      final jsonValue = value.toJson();
      final newValue = Pubspec.fromJson(jsonValue);

      expect(newValue.name, value.name);
      expect(newValue.version, value.version);
      expect(newValue.publishTo, value.publishTo);
      expect(newValue.description, value.description);
      expect(newValue.homepage, value.homepage);
      expect(newValue.author, value.author);
      expect(newValue.authors, value.authors);
      expect(newValue.environment, value.environment);
      expect(newValue.documentation, value.documentation);
      expect(newValue.dependencies, value.dependencies);
      expect(newValue.devDependencies, value.devDependencies);
      expect(newValue.dependencyOverrides, value.dependencyOverrides);
      expect(newValue.flutter, value.flutter);
      expect(newValue.repository, value.repository);
      expect(newValue.issueTracker, value.issueTracker);
      expect(newValue.screenshots, value.screenshots);
      expect(newValue.workspace, value.workspace);
      expect(newValue.resolution, value.resolution);
      expect(newValue.executables, value.executables);
    });

    test('all fields set', () async {
      final version = Version.parse('1.2.3');
      final sdkConstraint = VersionConstraint.parse('>=3.6.0 <4.0.0');
      final value = await parse({
        'name': 'sample',
        'version': version.toString(),
        'publish_to': 'none',
        'author': 'name@example.com',
        'environment': {'sdk': sdkConstraint.toString()},
        'description': 'description',
        'homepage': 'homepage',
        'documentation': 'documentation',
        'repository': 'https://github.com/example/repo',
        'issue_tracker': 'https://github.com/example/repo/issues',
        'funding': ['https://patreon.com/example'],
        'topics': ['widget', 'button'],
        'ignored_advisories': ['111', '222'],
        'screenshots': [
          {'description': 'my screenshot', 'path': 'path/to/screenshot'},
        ],
        'workspace': ['pkg1', 'pkg2'],
        'resolution': 'workspace',
        'executables': {
          'my_script': 'bin/my_script.dart',
          'my_script2': 'bin/my_script2.dart',
        },
        'dependencies': {'foo': '1.0.0'},
        'dev_dependencies': {'bar': '2.0.0'},
        'dependency_overrides': {'baz': '3.0.0'},
      }, skipTryPub: true);

      final jsonValue = value.toJson();

      final newValue = Pubspec.fromJson(jsonValue);

      expect(newValue.name, value.name);
      expect(newValue.version, value.version);
      expect(newValue.publishTo, value.publishTo);
      expect(newValue.description, value.description);
      expect(newValue.homepage, value.homepage);
      expect(newValue.author, value.author);
      expect(newValue.authors, value.authors);
      expect(newValue.environment, value.environment);
      expect(newValue.documentation, value.documentation);
      expect(newValue.dependencies, value.dependencies);
      expect(newValue.devDependencies, value.devDependencies);
      expect(newValue.dependencyOverrides, value.dependencyOverrides);
      expect(newValue.flutter, value.flutter);
      expect(newValue.repository, value.repository);
      expect(newValue.issueTracker, value.issueTracker);
      expect(newValue.screenshots?.length, value.screenshots?.length);
      expect(
        newValue.screenshots?.first.description,
        value.screenshots?.first.description,
      );
      expect(newValue.screenshots?.first.path, value.screenshots?.first.path);
      expect(newValue.workspace, value.workspace);
      expect(newValue.resolution, value.resolution);
      expect(newValue.executables, value.executables);
    });

    test('dependencies', () async {
      final value = await parse({
        ...defaultPubspec,
        'dependencies': {
          'flutter': {'sdk': 'flutter'},
          'http': '^1.1.0',
          'provider': {'version': '^6.0.5'},
          'firebase_core': {
            'hosted': {'name': 'firebase_core', 'url': 'https://pub.dev'},
            'version': '^2.13.0',
          },
          'google_fonts': {'sdk': 'flutter', 'version': '^4.0.3'},
          'flutter_bloc': {'git': 'https://github.com/felangel/bloc.git'},
          'shared_preferences': {
            'git': {
              'url': 'https://github.com/flutter/plugins.git',
              'ref': 'main',
              'path': 'packages/shared_preferences/shared_preferences',
            },
          },
          'local_utils': {'path': '../local_utils'},
        },
      }, skipTryPub: true);

      final jsonValue = value.toJson();

      final newValue = await parse(jsonValue, skipTryPub: true);

      expect(value.dependencies, hasLength(8));
      expect(value.dependencies, {
        'flutter': isA<SdkDependency>(),
        'http': isA<HostedDependency>(),
        'provider': isA<HostedDependency>(),
        'firebase_core': isA<HostedDependency>(),
        'google_fonts': isA<SdkDependency>(),
        'flutter_bloc': isA<GitDependency>(),
        'shared_preferences': isA<GitDependency>(),
        'local_utils': isA<PathDependency>(),
      });

      expect(
        value.dependencies['flutter']?.toJson(),
        newValue.dependencies['flutter']?.toJson(),
      );
      expect(
        value.dependencies['http']?.toJson(),
        newValue.dependencies['http']?.toJson(),
      );
      expect(
        value.dependencies['provider']?.toJson(),
        newValue.dependencies['provider']?.toJson(),
      );
      expect(
        value.dependencies['firebase_core']?.toJson(),
        newValue.dependencies['firebase_core']?.toJson(),
      );
      expect(
        value.dependencies['google_fonts']?.toJson(),
        newValue.dependencies['google_fonts']?.toJson(),
      );
      expect(
        value.dependencies['flutter_bloc']?.toJson(),
        newValue.dependencies['flutter_bloc']?.toJson(),
      );
      expect(
        value.dependencies['shared_preferences']?.toJson(),
        newValue.dependencies['shared_preferences']?.toJson(),
      );
      expect(
        value.dependencies['local_utils']?.toJson(),
        newValue.dependencies['local_utils']?.toJson(),
      );
    });
  });
}
