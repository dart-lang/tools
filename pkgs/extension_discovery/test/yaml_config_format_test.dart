// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart' show DeepCollectionEquality;

import 'package:extension_discovery/src/yaml_config_format.dart';
import 'package:test/test.dart';

void _testInvalid(String name, String yaml, {String match = ''}) {
  test(name, () {
    expect(
      () => parseYamlFromConfigFile(yaml),
      throwsA(isFormatException.having(
        (e) => e.message,
        'message',
        contains(match),
      )),
    );
  });
}

void _testValid(String name, String yaml) {
  test(name, () {
    parseYamlFromConfigFile(yaml);
  });
}

void main() {
  group('parseYamlFromConfigFile', () {
    group('root must be a map', () {
      _testInvalid('empty string', '', match: 'map');
      _testInvalid('null', 'null', match: 'map');
      _testInvalid('list', '[]', match: 'map');
      _testInvalid('number (1)', '42', match: 'map');
      _testInvalid('number (2)', '42.2', match: 'map');
      _testInvalid('bool (1)', 'true', match: 'map');
      _testInvalid('bool (2)', 'false', match: 'map');
      _testInvalid('string', '"hello world"', match: 'map');
    });

    _testInvalid('must not have alias', match: 'alias', '''
      keyA: &myref
        - value 1
        - value 2
      KeyB: *myref
    ''');

    // it works without aliases
    _testValid('listed inside a map is fine', '''
      keyA:
        - value 1
        - value 2
      KeyB:
        - value 1
        - value 2
    ''');

    _testValid('comments are cool', '''
      keyA:
        - value 1 # this is fine
        - value 2
    ''');

    _testInvalid(
        'Top-level map with integer keys is not allowed', match: 'key', '''
        42: "value"   # this is NOT fine
        43: true
    ''');

    _testValid('Map with quoted integer keys is fine', '''
        "42": "value"   # this is fine
        '43': true
    ''');

    _testInvalid('Map with integer keys is not allowed', match: 'key', '''
      keyA:
        - value 1 # this is fine
        - value 2
      KeyB:
        42: value 3 # this is NOT fine
    ''');

    _testInvalid('Map with list keys is not allowed', match: 'key', '''
      keyA:
        - [1, 2, 3] # this is fine, crazy but fine!
      keyB:
        [1, 2, 3]: value 3 # this is NOT fine
    ''');

    _testInvalid('Map with boolean keys is not allowed (1)', match: 'key', '''
      keyA: true
      keyB:
        true: value 3 # this is NOT fine
    ''');

    _testInvalid('Map with boolean keys is not allowed (2)', match: 'key', '''
      keyA: true
      keyB:
        false: value 3 # this is NOT fine
    ''');

    _testInvalid('Map with null keys is not allowed', match: 'key', '''
      keyA: null # fine
      keyB:
        null: value 3 # this is NOT fine
    ''');

    _testValid('complex structures is fine', '''
      keyA: |
        multi-line
        string
      keyB: 42    # number
      keyC: 42.2  # double
      keyD: [1, 2]
      keyE:
      - 1
      - 2
      keyF:
        k: "v"
    ''');

    test('complex structures matches the same JSON', () {
      final yaml = '''
        keyA: "hello"
        keyB: 42    # number
        keyC: 42.2  # double
        keyD: [1, 2]
        keyE:
        - 1
        - 2
        keyF:
          k: "v"
      ''';
      final data = parseYamlFromConfigFile(yaml);
      expect(
        DeepCollectionEquality().equals(data, {
          'keyA': 'hello',
          'keyB': 42,
          'keyC': 42.2,
          'keyD': [1, 2],
          'keyE': [1, 2],
          'keyF': {'k': 'v'},
        }),
        isTrue,
      );
    });
  });
}
