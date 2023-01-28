// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  final errors = <Message>[];

  tearDown(errors.clear);

  group('handles escape codes', () {
    group('in an identifier', () {
      test('with trailing space', () {
        final selectorAst = selector(r'.\35 00px', errors: errors);
        expect(errors, isEmpty);
        expect(compactOutput(selectorAst), r'.\35 00px');
      });

      test('in an attribute selector value', () {
        final selectorAst = selector(r'[elevation=\31]', errors: errors);
        expect(errors, isEmpty);
        expect(compactOutput(selectorAst), r'[elevation=\31]');
      });
    });
  });
}
