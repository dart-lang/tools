// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  test('unit-like type selectors are recognized from the first token', () {
    for (final name in ['px', 'fr', 'em', 'rem', 'ch', 'vw', 'dpi']) {
      final errors = <Message>[];
      final parsed = selector(name, errors: errors);
      expect(errors, isEmpty, reason: name);
      expect(compactOutput(parsed), name);
    }
  });

  test('first token of a selector group is in selector mode', () {
    final errors = <Message>[];
    final group = parseSelectorGroup('rem, vw, px', errors: errors);
    expect(errors, isEmpty);
    expect(group, isNotNull);
    expect(group!.selectors, hasLength(3));
  });

  test('unit-like type selectors start rule sets in a stylesheet', () {
    for (final input in [
      'rem{color:red}',
      'a{color:red}vw,a{color:red}',
      '@media screen{dpi{color:red}}',
    ]) {
      final errors = <Message>[];
      final sheet = parse(input, errors: errors);
      expect(errors, isEmpty, reason: input);
      expect(compactOutput(sheet), input, reason: input);
    }
  });
}
