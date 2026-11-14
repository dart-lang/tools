// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  test('namespace printer quotes the URI in pretty output', () {
    final errors = <Message>[];
    final sheet = parse(
      '@namespace svg "http://example.org/svg";',
      errors: errors,
    );
    expect(errors, isEmpty);
    expect(prettyPrint(sheet), '@namespace svg "http://example.org/svg";');
  });

  test('namespace printer keeps compact url() representation', () {
    final errors = <Message>[];
    final sheet = parse(
      '@namespace svg url(http://example.org/svg);',
      errors: errors,
    );
    expect(errors, isEmpty);
    expect(compactOutput(sheet), '@namespace svg url(http://example.org/svg);');
    expect(prettyPrint(sheet), '@namespace svg "http://example.org/svg";');
  });

  test('default namespace is separated from its URI', () {
    final errors = <Message>[];
    final sheet = parse('@namespace "http://example.org";', errors: errors);
    expect(errors, isEmpty);
    expect(prettyPrint(sheet), '@namespace "http://example.org";');
  });
}
