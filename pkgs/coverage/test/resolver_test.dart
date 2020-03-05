// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:coverage/src/resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Default Resolver', () {
    setUp(() async {
      await d.dir('foo', [
        d.file('.packages', '''
# Fake for testing!
foo:file:///${d.sandbox}/foo/lib
'''),
        d.file('.bad.packages', 'thisIsntAPackagesFile!'),
        d.dir('.dart_tool', [
          d.file('package_config.json', '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "foo",
      "rootUri": "file:///${d.sandbox}/foo",
      "packageUri": "lib/"
    }
  ]
}
'''),
        ]),
        d.dir('lib', [
          d.file('foo.dart', 'final foo = "bar";'),
        ]),
      ]).create();
    });

    test('can be created from a package_config.json', () async {
      final resolver = Resolver(
          packagesPath:
              p.join(d.sandbox, 'foo', '.dart_tool', 'package_config.json'));
      expect(resolver.resolve('package:foo/foo.dart'),
          '${d.sandbox}/foo/lib/foo.dart');
    });

    test('can be created from a .packages file', () async {
      final resolver =
          Resolver(packagesPath: p.join(d.sandbox, 'foo', '.packages'));
      expect(resolver.resolve('package:foo/foo.dart'),
          '${d.sandbox}/foo/lib/foo.dart');
    });

    test('errors if the packagesFile is an unknown format', () async {
      expect(
          () =>
              Resolver(packagesPath: p.join(d.sandbox, 'foo', '.bad.packages')),
          throwsA(isA<FormatException>()));
    });
  });

  group('Bazel resolver', () {
    const workspace = 'foo';
    final resolver = BazelResolver(workspacePath: workspace);

    test('does not resolve SDK URIs', () {
      expect(resolver.resolve('dart:convert'), null);
    });

    test('resolves third-party package URIs', () {
      expect(resolver.resolve('package:foo/bar.dart'),
          'third_party/dart/foo/lib/bar.dart');
      expect(resolver.resolve('package:foo/src/bar.dart'),
          'third_party/dart/foo/lib/src/bar.dart');
    });

    test('resolves non-third-party package URIs', () {
      expect(
          resolver.resolve('package:foo.bar/baz.dart'), 'foo/bar/lib/baz.dart');
      expect(resolver.resolve('package:foo.bar/src/baz.dart'),
          'foo/bar/lib/src/baz.dart');
    });

    test('resolves file URIs', () {
      expect(
          resolver
              .resolve('file://x/y/z.runfiles/$workspace/foo/bar/lib/baz.dart'),
          'foo/bar/lib/baz.dart');
      expect(
          resolver.resolve(
              'file://x/y/z.runfiles/$workspace/foo/bar/lib/src/baz.dart'),
          'foo/bar/lib/src/baz.dart');
    });

    test('resolves HTTPS URIs containing /packages/', () {
      expect(resolver.resolve('https://host:8080/a/b/packages/foo/bar.dart'),
          'third_party/dart/foo/lib/bar.dart');
      expect(
          resolver.resolve('https://host:8080/a/b/packages/foo/src/bar.dart'),
          'third_party/dart/foo/lib/src/bar.dart');
      expect(
          resolver.resolve('https://host:8080/a/b/packages/foo.bar/baz.dart'),
          'foo/bar/lib/baz.dart');
      expect(
          resolver
              .resolve('https://host:8080/a/b/packages/foo.bar/src/baz.dart'),
          'foo/bar/lib/src/baz.dart');
    });

    test('resolves HTTP URIs containing /packages/', () {
      expect(resolver.resolve('http://host:8080/a/b/packages/foo/bar.dart'),
          'third_party/dart/foo/lib/bar.dart');
      expect(resolver.resolve('http://host:8080/a/b/packages/foo/src/bar.dart'),
          'third_party/dart/foo/lib/src/bar.dart');
      expect(resolver.resolve('http://host:8080/a/b/packages/foo.bar/baz.dart'),
          'foo/bar/lib/baz.dart');
      expect(
          resolver
              .resolve('http://host:8080/a/b/packages/foo.bar/src/baz.dart'),
          'foo/bar/lib/src/baz.dart');
    });

    test('resolves HTTPS URIs without /packages/', () {
      expect(
          resolver
              .resolve('https://host:8080/third_party/dart/foo/lib/bar.dart'),
          'third_party/dart/foo/lib/bar.dart');
      expect(
          resolver.resolve(
              'https://host:8080/third_party/dart/foo/lib/src/bar.dart'),
          'third_party/dart/foo/lib/src/bar.dart');
      expect(resolver.resolve('https://host:8080/foo/lib/bar.dart'),
          'foo/lib/bar.dart');
      expect(resolver.resolve('https://host:8080/foo/lib/src/bar.dart'),
          'foo/lib/src/bar.dart');
    });

    test('resolves HTTP URIs without /packages/', () {
      expect(
          resolver
              .resolve('http://host:8080/third_party/dart/foo/lib/bar.dart'),
          'third_party/dart/foo/lib/bar.dart');
      expect(
          resolver.resolve(
              'http://host:8080/third_party/dart/foo/lib/src/bar.dart'),
          'third_party/dart/foo/lib/src/bar.dart');
      expect(resolver.resolve('http://host:8080/foo/lib/bar.dart'),
          'foo/lib/bar.dart');
      expect(resolver.resolve('http://host:8080/foo/lib/src/bar.dart'),
          'foo/lib/src/bar.dart');
    });
  });
}
