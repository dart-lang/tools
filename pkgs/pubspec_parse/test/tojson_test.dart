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

      expect(jsonValue['name'], 'sample');
      expect(jsonValue['version'], isNull);
      expect(jsonValue['publishTo'], isNull);
      expect(jsonValue['description'], isNull);
      expect(jsonValue['homepage'], isNull);
      expect(jsonValue['author'], isNull);
      expect(jsonValue['authors'], isEmpty);
      expect(jsonValue['environment'], {'sdk': '>=2.12.0 <3.0.0'});
      expect(jsonValue['documentation'], isNull);
      expect(jsonValue['dependencies'], isEmpty);
      expect(jsonValue['dev_dependencies'], isEmpty);
      expect(jsonValue['dependency_overrides'], isEmpty);
      expect(jsonValue['flutter'], isNull);
      expect(jsonValue['repository'], isNull);
      expect(jsonValue['issue_tracker'], isNull);
      expect(jsonValue['screenshots'], isEmpty);
      expect(jsonValue['workspace'], isNull);
      expect(jsonValue['resolution'], isNull);
      expect(jsonValue['executables'], isEmpty);
    });

    test('all fields set', () async {
      final version = Version.parse('1.2.3');
      final sdkConstraint = VersionConstraint.parse('>=3.6.0 <4.0.0');

      final value = await parse(
        {
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
        },
        skipTryPub: true,
      );

      final jsonValue = value.toJson();

      expect(jsonValue['name'], 'sample');
      expect(jsonValue['version'], version.toString());
      expect(jsonValue['publish_to'], 'none');
      expect(jsonValue['description'], 'description');
      expect(jsonValue['homepage'], 'homepage');
      expect(jsonValue['author'], 'name@example.com');
      expect(jsonValue['authors'], ['name@example.com']);
      expect(
        jsonValue['environment'],
        containsPair('sdk', sdkConstraint.toString()),
      );
      expect(jsonValue['documentation'], 'documentation');
      expect(jsonValue['dependencies'], hasLength(1));
      expect(
        jsonValue['dependencies'],
        containsPair('foo', {'version': '1.0.0'}),
      );
      expect(jsonValue['dev_dependencies'], hasLength(1));
      expect(
        jsonValue['dev_dependencies'],
        containsPair('bar', {
          'version': '2.0.0',
        }),
      );
      expect(jsonValue['dependency_overrides'], hasLength(1));
      expect(
        jsonValue['dependency_overrides'],
        containsPair('baz', {
          'version': '3.0.0',
        }),
      );
      expect(jsonValue['repository'], 'https://github.com/example/repo');
      expect(
        jsonValue['issue_tracker'],
        'https://github.com/example/repo/issues',
      );
      expect(jsonValue['funding'], ['https://patreon.com/example']);
      expect(jsonValue['topics'], ['widget', 'button']);
      expect(jsonValue['ignored_advisories'], ['111', '222']);
      expect(jsonValue['screenshots'], [
        {'description': 'my screenshot', 'path': 'path/to/screenshot'},
      ]);
      expect(jsonValue['workspace'], ['pkg1', 'pkg2']);
      expect(jsonValue['resolution'], 'workspace');
      expect(jsonValue['executables'], {
        'my_script': 'bin/my_script.dart',
        'my_script2': 'bin/my_script2.dart',
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
      final value = await parse(
        {
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
        },
        skipTryPub: true,
      );

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
      final value = await parse(
        {
          ...defaultPubspec,
          'dependencies': {
            'flutter': {
              'sdk': 'flutter',
            },
            'http': '^1.1.0',
            'provider': {
              'version': '^6.0.5',
            },
            'firebase_core': {
              'hosted': {
                'name': 'firebase_core',
                'url': 'https://pub.dev',
              },
              'version': '^2.13.0',
            },
            'google_fonts': {
              'sdk': 'flutter',
              'version': '^4.0.3',
            },
            'flutter_bloc': {
              'git': 'https://github.com/felangel/bloc.git',
            },
            'shared_preferences': {
              'git': {
                'url': 'https://github.com/flutter/plugins.git',
                'ref': 'main',
                'path': 'packages/shared_preferences/shared_preferences',
              },
            },
            'local_utils': {
              'path': '../local_utils',
            },
          },
        },
        skipTryPub: true,
      );

      final jsonValue = value.toJson();

      final newValue = await parse(jsonValue, skipTryPub: true);

      expect(value.dependencies, hasLength(8));
      expect(value.dependencies['flutter'], isA<SdkDependency>());
      expect(value.dependencies['http'], isA<HostedDependency>());
      expect(value.dependencies['provider'], isA<HostedDependency>());
      expect(value.dependencies['firebase_core'], isA<HostedDependency>());
      expect(value.dependencies['google_fonts'], isA<SdkDependency>());
      expect(value.dependencies['flutter_bloc'], isA<GitDependency>());
      expect(value.dependencies['shared_preferences'], isA<GitDependency>());
      expect(value.dependencies['local_utils'], isA<PathDependency>());

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
