// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:snippets/src/indent.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('strips the shared indentation', () {
    check(stripIndentation('''
  final x = 1;
  if (x == 1) {
    print(x);
  }
''')).equals('''
final x = 1;
if (x == 1) {
  print(x);
}
''');
  });

  test('blank and whitespace-only lines do not defeat dedenting', () {
    check(stripIndentation('  a;\n\n    \n  b;\n')).equals('a;\n\n\nb;\n');
  });

  test('mixed tabs and spaces only lose what they share', () {
    check(stripIndentation('\t a;\n\t b;\n')).equals('a;\nb;\n');
    check(stripIndentation('\ta;\n  b;\n')).equals('\ta;\n  b;\n');
  });

  test('leaves unindented and empty strings alone', () {
    check(stripIndentation('')).equals('');
    check(stripIndentation('a;\nb;\n')).equals('a;\nb;\n');
  });
}
