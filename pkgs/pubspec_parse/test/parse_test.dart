// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('trival', () {
    var value = parse({'name': 'sample'});
    expect(value.name, 'sample');
    expect(value.authors, isEmpty);
    expect(value.dependencies, isEmpty);
  });

  test('one author', () {
    var value = parse({'name': 'sample', 'author': 'name@example.com'});
    expect(value.allAuthors, ['name@example.com']);
  });

  test('one author, via authors', () {
    var value = parse({
      'name': 'sample',
      'authors': ['name@example.com']
    });
    expect(value.authors, ['name@example.com']);
  });

  test('many authors', () {
    var value = parse({
      'name': 'sample',
      'authors': ['name@example.com', 'name2@example.com']
    });
    expect(value.authors, ['name@example.com', 'name2@example.com']);
  });

  test('author and authors', () {
    var value = parse({
      'name': 'sample',
      'author': 'name@example.com',
      'authors': ['name2@example.com']
    });
    expect(value.allAuthors, ['name@example.com', 'name2@example.com']);
  });

  group('invalid', () {
    test('null', () {
      expect(() => parse(null), throwsArgumentError);
    });
    test('empty string', () {
      expect(() => parse(''), throwsArgumentError);
    });
    test('array', () {
      expectParseThrows([], r'''
line 1, column 1: Does not represent a YAML map.
[]
^^''');
    });

    test('missing name', () {
      expectParseThrows({}, r'''
line 1, column 1: "name" cannot be empty.
{}
^^''');
    });

    test('"dart" is an invalid environment key', () {
      expectParseThrows({
        'name': 'sample',
        'environment': {'dart': 'cool'}
      }, r'''
line 4, column 3: Use "sdk" to for Dart SDK constraints.
  "dart": "cool"
  ^^^^^^''');
    });

    test('invalid version', () {
      expectParseThrows({'name': 'sample', 'version': 'invalid'}, r'''
line 3, column 13: Unsupported value for `version`.
 "version": "invalid"
            ^^^^^^^^^''');
    });

    test('invalid environment value', () {
      expectParseThrows({
        'name': 'sample',
        'environment': {'sdk': 'silly'}
      }, r'''
line 4, column 10: Could not parse version "silly". Unknown text at "silly".
  "sdk": "silly"
         ^^^^^^^''');
    });
  });
}
