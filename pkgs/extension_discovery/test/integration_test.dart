// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;
import 'dart:isolate' show Isolate;

import 'package:test/test.dart';

import 'test_descriptor.dart' as d;

typedef Ext = ({
  String package,
  String rootUri,
  String packageUri,
  dynamic config
});

void main() {
  test('findExtensions', () async {
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
      d.dir('bin', [
        d.file('find_extensions.dart', '''
import 'dart:convert' show JsonEncoder;
import 'package:extension_discovery/extension_discovery.dart';

Future<void> main(List<String> args) async {
  final extensions = await findExtensions(args.first);
  print(JsonEncoder.withIndent('  ').convert([
    for (final e in extensions)
      {
        'package': e.package,
        'rootUri': e.rootUri.toString(),
        'packageUri': e.packageUri.toString(),
        'config': e.config,
      },
  ]));
}
        '''),
      ])
    ]).create();

    Future<List<Ext>> findExtensionsInSandbox(String target) async {
      final out = await d.dart(
        d.path('myapp/bin/find_extensions.dart'),
        target,
      );
      return (jsonDecode(out) as List<Object?>)
          .cast<Map>()
          .map((e) => (
                package: e['package'] as String,
                rootUri: e['rootUri'] as String,
                packageUri: e['packageUri'] as String,
                config: e['config'],
              ))
          .toList();
    }

    // Get dependencies
    await d.dartPubGet(d.path('myapp'));

    // Check that we don't find any extensions
    expect(await findExtensionsInSandbox('myapp'), isEmpty);

    // Check that there is a myapp.json cache file
    await d
        .file(
          'myapp/.dart_tool/extension_discovery/myapp.json',
          isNotEmpty,
        )
        .validate();

    // Check that there is README.md
    await d
        .file(
          'myapp/.dart_tool/extension_discovery/README.md',
          isNotEmpty,
        )
        .validate();

    // Create a foo package
    await d.dir('foo', [
      d.pubspec({
        'name': 'foo',
        'environment': {'sdk': '^3.0.0'},
      }),
      // It has a config.yaml for myapp
      d.dir('extension/myapp', [
        d.json('config.yaml', {'fromFoo': true}),
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
    final ext = await findExtensionsInSandbox('myapp');
    expect(ext, isNotEmpty);
    expect(
      ext.any(
        (e) =>
            e.package == 'foo' &&
            e.rootUri == d.directoryUri('foo/').toString() &&
            e.packageUri == Uri.parse('lib/').toString() &&
            (e.config as Map)['fromFoo'] == true,
      ),
      isTrue,
    );
  });
}
