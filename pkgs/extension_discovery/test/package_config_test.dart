// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:extension_discovery/src/package_config.dart';
import 'package:test/test.dart';

import 'test_descriptor.dart' as d;

void main() {
  test('loadPackageConfig', () async {
    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {},
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    final packageConfigFile = d.file('myapp/.dart_tool/package_config.json').io;

    // Loading before `dart pub get` throws PackageConfigException
    expect(
      loadPackageConfig(packageConfigFile),
      throwsA(isA<PackageConfigException>()),
    );

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Parse package_config
    {
      final packages = await loadPackageConfig(packageConfigFile);
      expect(packages, isNotEmpty);
      expect(packages.any((p) => p.name == 'myapp'), isTrue);
      expect(packages.any((p) => p.name == 'foo'), isFalse);
      expect(packages.any((p) => p.name == 'bar'), isFalse);
    }

    // ################################## Create foo as relative path-dep
    await d.dir('foo', [
      d.pubspec({
        'name': 'foo',
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Update the pubspec.yaml with a dependency on foo
    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'foo': {'path': '../foo'},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Parse package_config
    {
      final packages = await loadPackageConfig(packageConfigFile);
      expect(packages, isNotEmpty);
      expect(packages.any((p) => p.name == 'myapp'), isTrue);
      expect(packages.any((p) => p.name == 'foo'), isTrue);
      expect(packages.any((p) => p.name == 'bar'), isFalse);
    }

    // ################################## Create bar as absolute path-dep

    await d.dir('bar', [
      d.pubspec({
        'name': 'bar',
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Update the pubspec.yaml with a dependency on foo
    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'foo': {'path': '../foo'},
          'bar': {'path': d.path('bar')},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Parse package_config
    {
      final packages = await loadPackageConfig(packageConfigFile);
      expect(packages, isNotEmpty);
      expect(packages.any((p) => p.name == 'myapp'), isTrue);
      expect(packages.any((p) => p.name == 'foo'), isTrue);
      expect(packages.any((p) => p.name == 'bar'), isTrue);
    }

    // ################################## Cannot read version 99

    {
      final pkgcfg = jsonDecode(packageConfigFile.readAsStringSync()) as Map;
      pkgcfg['configVersion'] = 99;
      packageConfigFile.writeAsStringSync(jsonEncode(pkgcfg));
    }

    // Loading before `dart pub get` throws PackageConfigException
    expect(
      loadPackageConfig(packageConfigFile),
      throwsA(isA<PackageConfigException>()),
    );

    // ################################## packageUri is optional

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    {
      final pkgcfg = jsonDecode(packageConfigFile.readAsStringSync()) as Map;
      for (final p in pkgcfg['packages'] as List) {
        (p as Map).remove('packageUri');
      }
      packageConfigFile.writeAsStringSync(jsonEncode(pkgcfg));
    }

    // Parse package_config
    {
      final packages = await loadPackageConfig(packageConfigFile);
      expect(packages, isNotEmpty);
      expect(packages.any((p) => p.name == 'myapp'), isTrue);
      expect(packages.any((p) => p.name == 'foo'), isTrue);
      expect(packages.any((p) => p.name == 'bar'), isTrue);
      expect(packages.every((p) => p.rootUri == p.packageUri), isTrue);
    }

    // ################################## packageUri is optional

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    {
      final pkgcfg = jsonDecode(packageConfigFile.readAsStringSync()) as Map;
      for (final p in pkgcfg['packages'] as List) {
        (p as Map).remove('rootUri');
      }
      packageConfigFile.writeAsStringSync(jsonEncode(pkgcfg));
    }

    // Loading before `dart pub get` throws PackageConfigException
    expect(
      loadPackageConfig(packageConfigFile),
      throwsA(isA<PackageConfigException>()),
    );
  });
}
