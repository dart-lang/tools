// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: lines_longer_than_80_chars

import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('minimal set values', () async {
    final value = await parse(defaultPubspec);
    expect(value.name, 'sample');
    expect(value.version, isNull);
    expect(value.publishTo, isNull);
    expect(value.description, isNull);
    expect(value.homepage, isNull);
    expect(value.author, isNull);
    expect(value.authors, isEmpty);
    expect(
      value.environment,
      {'sdk': VersionConstraint.parse('>=2.12.0 <3.0.0')},
    );
    expect(value.documentation, isNull);
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
    expect(value.flutter, isNull);
    expect(value.repository, isNull);
    expect(value.issueTracker, isNull);
    expect(value.screenshots, isEmpty);
  });

  test('all fields set', () async {
    final version = Version.parse('1.2.3');
    final sdkConstraint = VersionConstraint.parse('>=2.12.0 <3.0.0');
    final value = await parse({
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
      'funding': [
        'https://patreon.com/example',
      ],
      'topics': ['widget', 'button'],
      'ignored_advisories': ['111', '222'],
      'screenshots': [
        {'description': 'my screenshot', 'path': 'path/to/screenshot'},
      ],
    });
    expect(value.name, 'sample');
    expect(value.version, version);
    expect(value.publishTo, 'none');
    expect(value.description, 'description');
    expect(value.homepage, 'homepage');
    expect(value.author, 'name@example.com');
    expect(value.authors, ['name@example.com']);
    expect(value.environment, hasLength(1));
    expect(value.environment, containsPair('sdk', sdkConstraint));
    expect(value.documentation, 'documentation');
    expect(value.dependencies, isEmpty);
    expect(value.devDependencies, isEmpty);
    expect(value.dependencyOverrides, isEmpty);
    expect(value.repository, Uri.parse('https://github.com/example/repo'));
    expect(
      value.issueTracker,
      Uri.parse('https://github.com/example/repo/issues'),
    );
    expect(value.funding, hasLength(1));
    expect(value.funding!.single.toString(), 'https://patreon.com/example');
    expect(value.topics, hasLength(2));
    expect(value.topics!.first, 'widget');
    expect(value.topics!.last, 'button');
    expect(value.ignoredAdvisories, hasLength(2));
    expect(value.ignoredAdvisories!.first, '111');
    expect(value.ignoredAdvisories!.last, '222');
    expect(value.screenshots, hasLength(1));
    expect(value.screenshots!.first.description, 'my screenshot');
    expect(value.screenshots!.first.path, 'path/to/screenshot');
  });

  test('environment values can be null', () async {
    final value = await parse(
      {
        'name': 'sample',
        'environment': {
          'sdk': '>=2.12.0 <3.0.0',
          'bob': null,
        },
      },
      skipTryPub: true,
    );
    expect(value.name, 'sample');
    expect(value.environment, hasLength(2));
    expect(value.environment, containsPair('bob', isNull));
  });

  group('publish_to', () {
    for (var entry in {
      42: "Unsupported value for \"publish_to\". type 'int' is not a subtype of type 'String?'",
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
        expectParseThrowsContaining(
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
      'none': 'none',
    }.entries) {
      test('can be ${entry.key}', () async {
        final value = await parse({
          ...defaultPubspec,
          'publish_to': entry.value,
        });
        expect(value.publishTo, entry.value);
      });
    }
  });

  group('author, authors', () {
    test('one author', () async {
      final value = await parse({
        ...defaultPubspec,
        'author': 'name@example.com',
      });
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('one author, via authors', () async {
      final value = await parse({
        ...defaultPubspec,
        'authors': ['name@example.com'],
      });
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('many authors', () async {
      final value = await parse({
        ...defaultPubspec,
        'authors': ['name@example.com', 'name2@example.com'],
      });
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('author and authors', () async {
      final value = await parse({
        ...defaultPubspec,
        'author': 'name@example.com',
        'authors': ['name2@example.com'],
      });
      expect(value.author, isNull);
      expect(value.authors, ['name@example.com', 'name2@example.com']);
    });

    test('duplicate author values', () async {
      final value = await parse({
        ...defaultPubspec,
        'author': 'name@example.com',
        'authors': ['name@example.com', 'name@example.com'],
      });
      expect(value.author, 'name@example.com');
      expect(value.authors, ['name@example.com']);
    });

    test('flutter', () async {
      final value = await parse({
        ...defaultPubspec,
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
      expectParseThrows(
        [],
        r'''
line 1, column 1: Not a map
  ╷
1 │ []
  │ ^^
  ╵''',
      );
    });

    test('missing name', () {
      expectParseThrowsContaining(
        {},
        "Missing key \"name\". type 'Null' is not a subtype of type 'String'",
      );
    });

    test('null name value', () {
      expectParseThrowsContaining(
        {'name': null},
        "Unsupported value for \"name\". type 'Null' is not a subtype of type 'String'",
      );
    });

    test('empty name value', () {
      expectParseThrows(
        {'name': ''},
        r'''
line 2, column 10: Unsupported value for "name". "name" cannot be empty.
  ╷
2 │  "name": ""
  │          ^^
  ╵''',
      );
    });

    test('"dart" is an invalid environment key', () {
      expectParseThrows(
        {
          'name': 'sample',
          'environment': {'dart': 'cool'},
        },
        r'''
line 4, column 3: Use "sdk" to for Dart SDK constraints.
  ╷
4 │   "dart": "cool"
  │   ^^^^^^
  ╵''',
      );
    });

    test('environment values cannot be int', () {
      expectParseThrows(
        {
          'name': 'sample',
          'environment': {'sdk': 42},
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
      expectParseThrows(
        {
          'name': 'sample',
          'environment': {'sdk': 'silly'},
        },
        r'''
line 4, column 10: Unsupported value for "sdk". Could not parse version "silly". Unknown text at "silly".
  ╷
4 │   "sdk": "silly"
  │          ^^^^^^^
  ╵''',
      );
    });

    test('bad repository url', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'repository': {'x': 'y'},
        },
        "Unsupported value for \"repository\". type 'YamlMap' is not a subtype of type 'String'",
        skipTryPub: true,
      );
    });

    test('bad issue_tracker url', () {
      expectParseThrowsContaining(
        {
          'name': 'sample',
          'issue_tracker': {'x': 'y'},
        },
        "Unsupported value for \"issue_tracker\". type 'YamlMap' is not a subtype of type 'String'",
        skipTryPub: true,
      );
    });
  });

  group('funding', () {
    test('not a list', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'funding': 1,
        },
        "Unsupported value for \"funding\". type 'int' is not a subtype of type 'List<dynamic>?'",
        skipTryPub: true,
      );
    });

    test('not an uri', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'funding': [1],
        },
        "Unsupported value for \"funding\". type 'int' is not a subtype of type 'String'",
        skipTryPub: true,
      );
    });

    test('not an uri', () {
      expectParseThrows(
        {
          ...defaultPubspec,
          'funding': ['ht tps://example.com/'],
        },
        r'''
line 6, column 13: Unsupported value for "funding". Illegal scheme character at offset 2.
  ╷
6 │    "funding": [
  │ ┌─────────────^
7 │ │   "ht tps://example.com/"
8 │ └  ]
  ╵''',
        skipTryPub: true,
      );
    });
  });
  group('topics', () {
    test('not a list', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'topics': 1,
        },
        "Unsupported value for \"topics\". type 'int' is not a subtype of type 'List<dynamic>?'",
        skipTryPub: true,
      );
    });

    test('not a string', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'topics': [1],
        },
        "Unsupported value for \"topics\". type 'int' is not a subtype of type 'String'",
        skipTryPub: true,
      );
    });

    test('invalid data - lenient', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'topics': [1],
        },
        skipTryPub: true,
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.topics, isNull);
    });
  });

  group('ignored_advisories', () {
    test('not a list', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'ignored_advisories': 1,
        },
        "Unsupported value for \"ignored_advisories\". type 'int' is not a subtype of type 'List<dynamic>?'",
        skipTryPub: true,
      );
    });

    test('not a string', () {
      expectParseThrowsContaining(
        {
          ...defaultPubspec,
          'ignored_advisories': [1],
        },
        "Unsupported value for \"ignored_advisories\". type 'int' is not a subtype of type 'String'",
        skipTryPub: true,
      );
    });

    test('invalid data - lenient', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'ignored_advisories': [1],
        },
        skipTryPub: true,
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.ignoredAdvisories, isNull);
    });
  });

  group('screenshots', () {
    test('one screenshot', () async {
      final value = await parse({
        ...defaultPubspec,
        'screenshots': [
          {'description': 'my screenshot', 'path': 'path/to/screenshot'},
        ],
      });
      expect(value.screenshots, hasLength(1));
      expect(value.screenshots!.first.description, 'my screenshot');
      expect(value.screenshots!.first.path, 'path/to/screenshot');
    });

    test('many screenshots', () async {
      final value = await parse({
        ...defaultPubspec,
        'screenshots': [
          {'description': 'my screenshot', 'path': 'path/to/screenshot'},
          {
            'description': 'my second screenshot',
            'path': 'path/to/screenshot2',
          },
        ],
      });
      expect(value.screenshots, hasLength(2));
      expect(value.screenshots!.first.description, 'my screenshot');
      expect(value.screenshots!.first.path, 'path/to/screenshot');
      expect(value.screenshots!.last.description, 'my second screenshot');
      expect(value.screenshots!.last.path, 'path/to/screenshot2');
    });

    test('one screenshot plus invalid entries', () async {
      final value = await parse({
        ...defaultPubspec,
        'screenshots': [
          42,
          {
            'description': 'my screenshot',
            'path': 'path/to/screenshot',
            'extraKey': 'not important',
          },
          'not a screenshot',
        ],
      });
      expect(value.screenshots, hasLength(1));
      expect(value.screenshots!.first.description, 'my screenshot');
      expect(value.screenshots!.first.path, 'path/to/screenshot');
    });

    test('invalid entries', () async {
      final value = await parse({
        ...defaultPubspec,
        'screenshots': [
          42,
          'not a screenshot',
        ],
      });
      expect(value.screenshots, isEmpty);
    });

    test('missing key `dessription', () {
      expectParseThrows(
        {
          ...defaultPubspec,
          'screenshots': [
            {'path': 'my/path'},
          ],
        },
        r'''
line 7, column 3: Missing key "description". Missing required key `description`
  ╷
7 │ ┌   {
8 │ │    "path": "my/path"
9 │ └   }
  ╵''',
        skipTryPub: true,
      );
    });

    test('missing key `path`', () {
      expectParseThrows(
        {
          ...defaultPubspec,
          'screenshots': [
            {'description': 'my screenshot'},
          ],
        },
        r'''
line 7, column 3: Missing key "path". Missing required key `path`
  ╷
7 │ ┌   {
8 │ │    "description": "my screenshot"
9 │ └   }
  ╵''',
        skipTryPub: true,
      );
    });

    test('Value of description not a String`', () {
      expectParseThrows(
        {
          ...defaultPubspec,
          'screenshots': [
            {'description': 42},
          ],
        },
        r'''
line 8, column 19: Unsupported value for "description". `42` is not a String
  ╷
8 │      "description": 42
  │ ┌───────────────────^
9 │ │   }
  │ └──^
  ╵''',
        skipTryPub: true,
      );
    });

    test('Value of path not a String`', () {
      expectParseThrows(
        {
          ...defaultPubspec,
          'screenshots': [
            {
              'description': '',
              'path': 42,
            },
          ],
        },
        r'''
line 9, column 12: Unsupported value for "path". `42` is not a String
   ╷
9  │      "path": 42
   │ ┌────────────^
10 │ │   }
   │ └──^
   ╵''',
        skipTryPub: true,
      );
    });

    test('invalid screenshot - lenient', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'screenshots': 'Invalid value',
        },
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.screenshots, isEmpty);
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
      expectParseThrowsContaining(
        {},
        "Missing key \"name\". type 'Null' is not a subtype of type 'String'",
        lenient: true,
      );
    });

    test('bad repository url', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'repository': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.repository, isNull);
    });

    test('bad issue_tracker url', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'issue_tracker': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.issueTracker, isNull);
    });

    test('multiple bad values', () async {
      final value = await parse(
        {
          ...defaultPubspec,
          'repository': {'x': 'y'},
          'issue_tracker': {'x': 'y'},
        },
        lenient: true,
      );
      expect(value.name, 'sample');
      expect(value.repository, isNull);
      expect(value.issueTracker, isNull);
    });

    test('deep error throws with lenient', () {
      expect(
        () => parse(
          {
            'name': 'sample',
            'dependencies': {
              'foo': {
                'git': {'url': 1},
              },
            },
            'issue_tracker': {'x': 'y'},
          },
          skipTryPub: true,
          lenient: true,
        ),
        throwsException,
      );
    });
  });
}
