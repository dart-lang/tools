// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(kevmoo) Remove when github.com/dart-lang/sdk/commit/dac5a56422 lands
// in a shipped SDK.
// ignore_for_file: deprecated_member_use
library parse_test;

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('minimal set values', () {
    final value = parse({'name': 'sample'});
    expect(value.name, 'sample');
    expect(value.version, isNull);
    expect(value.publishTo, isNull);
    expect(value.description, isNull);
    expect(value.homepage, isNull);
    // ignore: deprecated_member_use_from_same_package
    expect(value.author, isNull);
    expect(value.authors, isEmpty);
    expect(value.environment, isEmpty);
    expect(value.documentation, isNull);
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
    expect(value.flutter, isNull);
    expect(value.repository, isNull);
    expect(value.issueTracker, isNull);
  });

  test('all fields set', () {
    final version = Version.parse('1.2.3');
    final sdkConstraint = VersionConstraint.parse('>=2.0.0-dev.54 <3.0.0');
    final value = parse({
      'name': 'sample',
      'version': version.toString(),
      'publish_to': 'none',
      'author': 'name@example.com',
      'environment': {'sdk': sdkConstraint.toString()},
      'description': 'description',
      'homepage': 'homepage',
      'documentation': 'documentation',
      'repository': 'https://github.com/example/repo',
      'issue_tracker': 'https://github.com/example/repo/issues',
    });
    expect(value.name, 'sample');
    expect(value.version, version);
    expect(value.publishTo, 'none');
    expect(value.description, 'description');
    expect(value.homepage, 'homepage');
    // ignore: deprecated_member_use_from_same_package
    expect(value.author, 'name@example.com');
    expect(value.authors, ['name@example.com']);
    expect(value.environment, hasLength(1));
    expect(value.environment, containsPair('sdk', sdkConstraint));
    expect(value.documentation, 'documentation');
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
    expect(value.repository, Uri.parse('https://github.com/example/repo'));
    expect(value.issueTracker,
        Uri.parse('https://github.com/example/repo/issues'));
  });

  test('environment values can be null', () {
    final value = parse({
      'name': 'sample',
      'environment': {'sdk': null}
    });
    expect(value.name, 'sample');
    expect(value.environment, hasLength(1));
    expect(value.environment, containsPair('sdk', isNull));
  });

  group('publish_to', () {
    for (var entry in {
      42: r'''
line 3, column 16: Unsupported value for "publish_to".
  ╷
3 │  "publish_to": 42
  │                ^^
  ╵''',
      '##not a uri!': r'''
line 3, column 16: Unsupported value for "publish_to". Must be an http or https URL.
  ╷
3 │  "publish_to": "##not a uri!"
  │                ^^^^^^^^^^^^^^
  ╵''',
      '/cool/beans': r'''
line 3, column 16: Unsupported value for "publish_to". Must be an http or https URL.
  ╷
3 │  "publish_to": "/cool/beans"
  │                ^^^^^^^^^^^^^
  ╵''',
      'file:///Users/kevmoo/': r'''
line 3, column 16: Unsupported value for "publish_to". Must be an http or https URL.
  ╷
3 │  "publish_to": "file:///Users/kevmoo/"
  │                ^^^^^^^^^^^^^^^^^^^^^^^
  ╵''',
    }.entries) {
      test('cannot be `${entry.key}`', () {
        expectParseThrows(
          {'name': 'sample', 'publish_to': entry.key},
          entry.value,
          skipTryPub: true,
        );
      });
    }

    for (var entry in {
      null: null,
      'http': 'http://example.com',
      'https': 'https://example.com',
      'none': 'none'
    }.entries) {
      test('can be ${entry.key}', () {
        final value = parse({'name': 'sample', 'publish_to': entry.value});
        expect(value.publishTo, entry.value);
      });
    }
  });

  group('author, authors', () {
    test('one author', () {
      final value = parse({'name': 'sample', 'author': 'name@example.com'});
      // ignore: deprecated_member_use_from_same_package
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('one author, via authors', () {
      final value = parse({
        'name': 'sample',
        'authors': ['name@example.com']
      });
      // ignore: deprecated_member_use_from_same_package
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('many authors', () {
      final value = parse({
        'name': 'sample',
        'authors': ['name@example.com', 'name2@example.com']
      });
      // ignore: deprecated_member_use_from_same_package
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('author and authors', () {
      final value = parse({
        'name': 'sample',
        'author': 'name@example.com',
        'authors': ['name2@example.com']
      });
      // ignore: deprecated_member_use_from_same_package
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('duplicate author values', () {
      final value = parse({
        'name': 'sample',
        'author': 'name@example.com',
        'authors': ['name@example.com', 'name@example.com']
      });
      // ignore: deprecated_member_use_from_same_package
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('flutter', () {
      final value = parse({
        'name': 'sample',
        'flutter': {'key': 'value'},
      });
      expect(value.flutter, {'key': 'value'});
    });
  });

  group('invalid', () {
    test('null', () {
      expectParseThrows(
        null,
        r'''
line 1, column 1: Not a map
  ╷
1 │ null
  │ ^^^^
  ╵''',
      );
    });
    test('empty string', () {
      expectParseThrows(
        '',
        r'''
line 1, column 1: Not a map
  ╷
1 │ ""
  │ ^^
  ╵''',
      );
    });
    test('array', () {
      expectParseThrows([], r'''
line 1, column 1: Not a map
  ╷
1 │ []
  │ ^^
  ╵''');
    });

    test('missing name', () {
      expectParseThrows({}, r'''
line 1, column 1: "name" cannot be empty.
  ╷
1 │ {}
  │ ^^
  ╵''');
    });

    test('"dart" is an invalid environment key', () {
      expectParseThrows({
        'name': 'sample',
        'environment': {'dart': 'cool'}
      }, r'''
line 4, column 3: Use "sdk" to for Dart SDK constraints.
  ╷
4 │   "dart": "cool"
  │   ^^^^^^
  ╵''');
    });

    test('environment values cannot be int', () {
      expectParseThrows(
        {
          'name': 'sample',
          'environment': {'sdk': 42}
        },
        r'''
line 4, column 10: Unsupported value for "sdk". `42` is not a String.
  ╷
4 │     "sdk": 42
  │ ┌──────────^
5 │ │  }
  │ └─^
  ╵''',
      );
    });

    test('version', () {
      expectParseThrows(
        {'name': 'sample', 'version': 'invalid'},
        r'''
line 3, column 13: Unsupported value for "version". Could not parse "invalid".
  ╷
3 │  "version": "invalid"
  │             ^^^^^^^^^
  ╵''',
      );
    });

    test('invalid environment value', () {
      expectParseThrows({
        'name': 'sample',
        'environment': {'sdk': 'silly'}
      }, r'''
line 4, column 10: Unsupported value for "sdk". Could not parse version "silly". Unknown text at "silly".
  ╷
4 │   "sdk": "silly"
  │          ^^^^^^^
  ╵''');
    });

    test('bad repository url', () {
      expectParseThrows(
        {
          'name': 'foo',
          'repository': {'x': 'y'},
        },
        r'''
line 3, column 16: Unsupported value for "repository".
  ╷
3 │    "repository": {
  │ ┌────────────────^
4 │ │   "x": "y"
5 │ └  }
  ╵''',
        skipTryPub: true,
      );
    });

    test('bad issue_tracker url', () {
      expectParseThrows(
        {
          'name': 'foo',
          'issue_tracker': {'x': 'y'},
        },
        r'''
line 3, column 19: Unsupported value for "issue_tracker".
  ╷
3 │    "issue_tracker": {
  │ ┌───────────────────^
4 │ │   "x": "y"
5 │ └  }
  ╵''',
        skipTryPub: true,
      );
    });
  });

  group('lenient', () {
    test('null', () {
      expectParseThrows(
        null,
        r'''
line 1, column 1: Not a map
  ╷
1 │ null
  │ ^^^^
  ╵''',
        lenient: true,
      );
    });

    test('empty string', () {
      expectParseThrows(
        '',
        r'''
line 1, column 1: Not a map
  ╷
1 │ ""
  │ ^^
  ╵''',
        lenient: true,
      );
    });

    test('name cannot be empty', () {
      expectParseThrows(
        {},
        r'''
line 1, column 1: "name" cannot be empty.
  ╷
1 │ {}
  │ ^^
  ╵''',
        lenient: true,
      );
    });

    test('bad repository url', () {
      final value = parse(
        {
          'name': 'foo',
          'repository': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'foo');
      expect(value.repository, isNull);
    });

    test('bad issue_tracker url', () {
      final value = parse(
        {
          'name': 'foo',
          'issue_tracker': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'foo');
      expect(value.issueTracker, isNull);
    });

    test('multiple bad values', () {
      final value = parse(
        {
          'name': 'foo',
          'repository': {'x': 'y'},
          'issue_tracker': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'foo');
      expect(value.repository, isNull);
      expect(value.issueTracker, isNull);
    });

    test('deep error throws with lenient', () {
      expect(
          () => parse({
                'name': 'foo',
                'dependencies': {
                  'foo': {
                    'git': {'url': 1}
                  },
                },
                'issue_tracker': {'x': 'y'},
              }, skipTryPub: true, lenient: true),
          throwsException);
    });
  });
}
