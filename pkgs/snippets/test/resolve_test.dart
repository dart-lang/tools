// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// These mirror dartdoc's `test/example_path_resolution_test.dart`, because
/// the two tools are supposed to accept the same references. A divergence
/// should show up here as a deliberate change, not as a surprise in someone's
/// repository.
library;

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:snippets/src/diagnostic.dart';
import 'package:snippets/src/resolve.dart';
import 'package:test/scaffolding.dart';

import 'checks_ext.dart';

const root = '/pkg';

String expected(String path) => p.normalize(p.absolute(path));

String resolve(String reference, {String document = '/pkg/README.md'}) =>
    resolveReference(
      packageRoot: root,
      documentPath: document,
      reference: reference,
    );

void main() {
  test('a relative path is relative to the document', () {
    check(resolve('example/hello.dart'))
        .equals(expected('/pkg/example/hello.dart'));
    check(resolve('hello.dart', document: '/pkg/doc/guide.md'))
        .equals(expected('/pkg/doc/hello.dart'));
    check(resolve('../example/hello.dart', document: '/pkg/doc/guide.md'))
        .equals(expected('/pkg/example/hello.dart'));
  });

  test('a leading slash is relative to the package root', () {
    check(resolve('/example/hello.dart', document: '/pkg/doc/deep/guide.md'))
        .equals(expected('/pkg/example/hello.dart'));
  });

  test('`.` segments are normalised away', () {
    check(resolve('./example/./hello.dart'))
        .equals(expected('/pkg/example/hello.dart'));
  });

  test('`..` is clamped at the package root', () {
    // URI resolution runs out of path rather than escaping, which is what
    // dartdoc relies on; the `isWithin` check below is the safety net.
    check(resolve('../../../etc/passwd')).equals(expected('/pkg/etc/passwd'));
  });

  test('percent-encoding is decoded', () {
    check(resolve('example/hello%20world.dart'))
        .equals(expected('/pkg/example/hello world.dart'));
  });

  test('spaces in the document directory are not double-encoded', () {
    check(resolve('hello.dart', document: '/pkg/docs dir/guide.md'))
        .equals(expected('/pkg/docs dir/hello.dart'));
  });

  test('the fragment is not part of the path', () {
    check(resolve('example/hello.dart#greeting'))
        .equals(expected('/pkg/example/hello.dart'));
  });

  test('a scheme is an error', () {
    check(() => resolve('file:///etc/passwd'))
        .throws<ExampleFormatException>()
        .message
        .contains('scheme');
    check(() => resolve('https://example.com/hello.dart'))
        .throws<ExampleFormatException>();
  });

  test('an authority is an error', () {
    check(() => resolve('//example.com/hello.dart'))
        .throws<ExampleFormatException>()
        .message
        .contains('authority');
  });

  test('an empty reference is an error', () {
    check(() => resolve('')).throws<ExampleFormatException>();
    check(() => resolve('#region')).throws<ExampleFormatException>();
  });
}
