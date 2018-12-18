// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('minimal set values', () {
    var value = parse({'name': 'sample'});
    expect(value.name, 'sample');
    expect(value.version, isNull);
    expect(value.description, isNull);
    expect(value.homepage, isNull);
    // ignore: deprecated_member_use
    expect(value.author, isNull);
    expect(value.authors, isEmpty);
    expect(value.environment, isEmpty);
    expect(value.documentation, isNull);
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
  });

  test('all fields set', () {
    var version = Version.parse('1.2.3');
    var sdkConstraint = VersionConstraint.parse('>=2.0.0-dev.54 <3.0.0');
    var value = parse({
      'name': 'sample',
      'version': version.toString(),
      'author': 'name@example.com',
      'environment': {'sdk': sdkConstraint.toString()},
      'description': 'description',
      'homepage': 'homepage',
      'documentation': 'documentation'
    });
    expect(value.name, 'sample');
    expect(value.version, version);
    expect(value.description, 'description');
    expect(value.homepage, 'homepage');
    // ignore: deprecated_member_use
    expect(value.author, 'name@example.com');
    expect(value.authors, ['name@example.com']);
    expect(value.environment, hasLength(1));
    expect(value.environment, containsPair('sdk', sdkConstraint));
    expect(value.documentation, 'documentation');
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
  });

  test('environment values can be null', () {
    var value = parse({
      'name': 'sample',
      'environment': {'sdk': null}
    });
    expect(value.name, 'sample');
    expect(value.environment, hasLength(1));
    expect(value.environment, containsPair('sdk', isNull));
  });

  group('author, authors', () {
    test('one author', () {
      var value = parse({'name': 'sample', 'author': 'name@example.com'});
      // ignore: deprecated_member_use
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('one author, via authors', () {
      var value = parse({
        'name': 'sample',
        'authors': ['name@example.com']
      });
      // ignore: deprecated_member_use
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('many authors', () {
      var value = parse({
        'name': 'sample',
        'authors': ['name@example.com', 'name2@example.com']
      });
      // ignore: deprecated_member_use
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('author and authors', () {
      var value = parse({
        'name': 'sample',
        'author': 'name@example.com',
        'authors': ['name2@example.com']
      });
      // ignore: deprecated_member_use
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('duplicate author values', () {
      var value = parse({
        'name': 'sample',
        'author': 'name@example.com',
        'authors': ['name@example.com', 'name@example.com']
      });
      // ignore: deprecated_member_use
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });
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

    test('environment values cannot be int', () {
      expectParseThrows({
        'name': 'sample',
        'environment': {'sdk': 42}
      }, r'''
line 4, column 10: `42` is not a String.
  "sdk": 42
         ^^^''');
    });

    test('version', () {
      expectParseThrows({'name': 'sample', 'version': 'invalid'}, r'''
line 3, column 13: Could not parse "invalid".
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
