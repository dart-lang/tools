// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

import 'utils/utils.dart';

Matcher _throwsAssertionError(messageMatcher) =>
    throwsA(const TypeMatcher<AssertionError>()
        .having((ae) => ae.message, 'message', messageMatcher));

void main() {
  const graph = <String, List<String>>{
    '1': ['2', '5'],
    '2': ['3'],
    '3': ['4', '5'],
    '4': ['1'],
    '5': ['8'],
    '6': ['7'],
  };

  List<String> getValues(String key) => graph[key] ?? [];

  List<X> getXValues(X key) =>
      graph[key.value]?.map((v) => X(v))?.toList() ?? [];

  test('null `start` throws AssertionError', () {
    expect(() => shortestPath(null, '1', getValues),
        _throwsAssertionError('`start` cannot be null'));
    expect(() => shortestPaths(null, getValues),
        _throwsAssertionError('`start` cannot be null'));
  });

  test('null `edges` throws AssertionError', () {
    expect(() => shortestPath(1, 1, null),
        _throwsAssertionError('`edges` cannot be null'));
    expect(() => shortestPaths(1, null),
        _throwsAssertionError('`edges` cannot be null'));
  });

  test('null return value from `edges` throws', () {
    expect(shortestPath(1, 1, (input) => null), [],
        reason: 'self target short-circuits');
    expect(shortestPath(1, 1, (input) => [null]), [],
        reason: 'self target short-circuits');

    expect(() => shortestPath(1, 2, (input) => null), throwsNoSuchMethodError);

    expect(() => shortestPaths(1, (input) => null), throwsNoSuchMethodError);

    expect(() => shortestPath(1, 2, (input) => [null]),
        _throwsAssertionError('`edges` cannot return null values.'));
    expect(() => shortestPaths(1, (input) => [null]),
        _throwsAssertionError('`edges` cannot return null values.'));
  });

  void _singlePathTest(String from, String to, List<String> expected) {
    test('$from -> $to should be $expected (mapped)', () {
      expect(
          shortestPath<X>(X(from), X(to), getXValues,
                  equals: xEquals, hashCode: xHashCode)
              ?.map((x) => x.value),
          expected);
    });

    test('$from -> $to should be $expected', () {
      expect(shortestPath(from, to, getValues), expected);
    });
  }

  void _pathsTest(
      String from, Map<String, List<String>> expected, List<String> nullPaths) {
    test('paths from $from (mapped)', () {
      final result = shortestPaths<X>(X(from), getXValues,
              equals: xEquals, hashCode: xHashCode)
          .map((k, v) => MapEntry(k.value, v.map((x) => x.value).toList()));
      expect(result, expected);
    });

    test('paths from $from', () {
      final result = shortestPaths(from, getValues);
      expect(result, expected);
    });

    for (var entry in expected.entries) {
      _singlePathTest(from, entry.key, entry.value);
    }

    for (var entry in nullPaths) {
      _singlePathTest(from, entry, null);
    }
  }

  _pathsTest('1', {
    '5': ['5'],
    '3': ['2', '3'],
    '8': ['5', '8'],
    '1': [],
    '2': ['2'],
    '4': ['2', '3', '4'],
  }, [
    '6',
    '7',
  ]);

  _pathsTest('6', {
    '7': ['7'],
    '6': [],
  }, [
    '1',
  ]);
  _pathsTest('7', {'7': []}, ['1', '6']);

  _pathsTest('42', {'42': []}, ['1', '6']);

  _singlePathTest('1', null, null);
}
