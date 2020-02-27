// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:coverage/src/resolver.dart';
import 'package:test/test.dart';

void main() {
  group('Default Resolver', () {
    test('can be created from a package_config.json', () async {
      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      expect(
          Uri.file(resolver.resolve('package:coverage/coverage.dart')),
          await Isolate.resolvePackageUri(
              Uri.parse('package:coverage/coverage.dart')));
    });

    test('can be created from a .packages file', () async {
      final resolver = Resolver(packagesPath: '.packages');
      expect(
          Uri.file(resolver.resolve('package:coverage/coverage.dart')),
          await Isolate.resolvePackageUri(
              Uri.parse('package:coverage/coverage.dart')));
    });

    test('errors if the packagesFile is an unknown format', () async {
      final tempDir = await Directory.systemTemp.createTemp('coverage_tests');
      addTearDown(() => tempDir.delete(recursive: true));
      final packagesFile = File.fromUri(tempDir.uri.resolve('.packages'));
      await packagesFile.create();
      await packagesFile.writeAsString('thisIsntAPackagesFile!');
      expect(() => Resolver(packagesPath: packagesFile.path),
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
