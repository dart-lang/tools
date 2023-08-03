// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate' show Isolate;

import 'package:extension_discovery/extension_discovery.dart';
import 'package:extension_discovery/src/io.dart';
import 'package:test/test.dart';

import 'test_descriptor.dart' as d;

void main() {
  test('findExtensions', () async {
    // Override the maturity delay for reliable testing of caching logic.
    modificationMaturityDelay = Duration(milliseconds: 50);

    final pkgLibDir = await Isolate.resolvePackageUri(
      Uri.parse('package:extension_discovery/'),
    );
    final pkgDir = pkgLibDir!.resolve('..');

    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'extension_discovery': {'path': pkgDir.toFilePath()},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Check that we don't find any extensions
    expect(
        await findExtensions(
          'myapp',
          packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
        ),
        isEmpty);

    // Check that there is a myapp.json cache file
    await d
        .file(
          'myapp/.dart_tool/extension_discovery/myapp.json',
          isNotEmpty,
        )
        .validate();

    // ################################## Create foo that provides extension
    await d.dir('foo', [
      d.pubspec({
        'name': 'foo',
        'environment': {'sdk': '^3.0.0'},
      }),
      // It has a config.json for myapp
      d.dir('extension/myapp', [
        d.json('config.json', {'fromFoo': true}),
      ]),
    ]).create();

    // Update the pubspec.yaml with a dependency on foo
    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'extension_discovery': {'path': pkgDir.toFilePath()},
          'foo': {'path': '../foo'},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Check that we do find an extension
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isNotEmpty);
      expect(
        ext.any(
          (e) =>
              e.package == 'foo' &&
              e.rootUri == d.directoryUri('foo/') &&
              e.packageUri == Uri.parse('lib/') &&
              (e.config as Map)['fromFoo'] == true,
        ),
        isTrue,
      );
    }

    // ################################## Modify the config
    await d.json('foo/extension/myapp/config.json', {'fromFoo': 42}).create();

    // Check that we do find an extension
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isNotEmpty);
      expect(
        ext.any(
          (e) =>
              e.package == 'foo' &&
              e.rootUri == d.directoryUri('foo/') &&
              e.packageUri == Uri.parse('lib/') &&
              (e.config as Map)['fromFoo'] == 42,
        ),
        isTrue,
      );
    }

    // ################################## Make config invalid
    await d.file('foo/extension/myapp/config.json', 'invalid json').create();

    // Check that we do not find extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isEmpty);
    }

    // ################################## Make config valid again
    await d.json('foo/extension/myapp/config.json', true).create();

    // Check that we do find extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isNotEmpty);
    }

    // ################################## Remove config file
    await d.file('foo/extension/myapp/config.json').io.delete();
    // Check that we do not find extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isEmpty);
    }

    // ################################## Make config valid again
    await d.json('foo/extension/myapp/config.json', {'fromFoo': true}).create();

    // Check that we do find extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isNotEmpty);
    }

    // ################################## Create bar as absolute path-dep
    await d.dir('bar', [
      d.pubspec({
        'name': 'bar',
        'environment': {'sdk': '^3.0.0'},
      }),
      // It has a config.json for myapp
      d.dir('extension/myapp', [
        d.json('config.json', {'fromFoo': false}),
      ]),
    ]).create();

    // Update the pubspec.yaml with a dependency on foo
    await d.dir('myapp', [
      d.pubspec({
        'name': 'myapp',
        'dependencies': {
          'extension_discovery': {'path': pkgDir.toFilePath()},
          'foo': {'path': '../foo'},
          'bar': {'path': d.path('bar')},
        },
        'environment': {'sdk': '^3.0.0'},
      }),
    ]).create();

    // We won't find bar without running `dart pub get`
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext.any((e) => e.package == 'bar'), isFalse);
    }

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Check that we do find both extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext, isNotEmpty);
      expect(
        ext.any(
          (e) =>
              e.package == 'foo' &&
              e.rootUri == d.directoryUri('foo/') &&
              e.packageUri == Uri.parse('lib/') &&
              (e.config as Map)['fromFoo'] == true,
        ),
        isTrue,
      );
      expect(
        ext.any(
          (e) =>
              e.package == 'bar' &&
              e.rootUri == d.directoryUri('bar/') &&
              e.packageUri == Uri.parse('lib/') &&
              (e.config as Map)['fromFoo'] == false,
        ),
        isTrue,
      );
    }

    // ################################## Changes to bar are not detected
    await d.file('bar/extension/myapp/config.json').io.delete();

    // Ensure that we wait long enough for the cache to be trusted,
    // this delay is to make sure that the logic we have handling races isn't
    // triggered. Think of it as waiting...
    await Future.delayed(modificationMaturityDelay);
    await Future.delayed(modificationMaturityDelay);

    // Check that we do find both extensions
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext.any((e) => e.package == 'foo'), isTrue);
      expect(ext.any((e) => e.package == 'bar'), isTrue);
    }

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // We won't find bar after `dart pub get`, because we removed the config
    {
      final ext = await findExtensions(
        'myapp',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext.any((e) => e.package == 'foo'), isTrue);
      expect(ext.any((e) => e.package == 'bar'), isFalse);
    }

    // ################################## Sanity check bar and foo
    expect(
      await findExtensions(
        'foo',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      ),
      isEmpty,
    );
    expect(
      await findExtensions(
        'bar',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      ),
      isEmpty,
    );

    // ################################## What if foo has extensions for bar
    await d.dir('foo/extension/bar', [
      d.json('config.json', {'fromFoo': true}),
    ]).create();

    {
      final ext = await findExtensions(
        'bar',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext.any((e) => e.package == 'foo'), isTrue);
      expect(ext.any((e) => e.package == 'bar'), isFalse);
      expect(ext.any((e) => e.package == 'myapp'), isFalse);
    }

    // ################################## myapp could also extend bar
    await d.dir('myapp/extension/bar', [
      d.json('config.json', {'fromFoo': false}),
    ]).create();

    {
      final ext = await findExtensions(
        'bar',
        packageConfig: d.fileUri('myapp/.dart_tool/package_config.json'),
      );
      expect(ext.any((e) => e.package == 'foo'), isTrue);
      expect(ext.any((e) => e.package == 'bar'), isFalse);
      expect(ext.any((e) => e.package == 'myapp'), isTrue);
    }
  });
}
