// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

Matcher _throwsAssertionError(messageMatcher) =>
    throwsA(const TypeMatcher<AssertionError>()
        .having((ae) => ae.message, 'message', messageMatcher));

String _identity(int input) => input.toString();

void main() {
  const graph = <int, List<int>>{
    1: [2, 5],
    2: [3],
    3: [4, 5],
    4: [1],
    5: [8],
    6: [7],
  };

  test('null `start` throws AssertionError', () {
    expect(
        () => shortestPath<String, int>(
            null, 1, _identity, (input) => graph[input] ?? []),
        _throwsAssertionError('`start` cannot be null'));
    expect(
        () => shortestPaths<String, int>(
            null, _identity, (input) => graph[input] ?? []),
        _throwsAssertionError('`start` cannot be null'));
  });

  test('null `edges` throws AssertionError', () {
    expect(() => shortestPath(1, 1, _identity, null),
        _throwsAssertionError('`edges` cannot be null'));
    expect(() => shortestPaths(1, _identity, null),
        _throwsAssertionError('`edges` cannot be null'));
  });

  test('null return value from `edges` throws', () {
    expect(shortestPath(1, 1, _identity, (input) => null), [],
        reason: 'self target short-circuits');
    expect(shortestPath(1, 1, _identity, (input) => [null]), [],
        reason: 'self target short-circuits');

    expect(() => shortestPath(1, 2, _identity, (input) => null),
        throwsNoSuchMethodError);

    expect(() => shortestPaths(1, _identity, (input) => null),
        throwsNoSuchMethodError);

    expect(() => shortestPath(1, 2, _identity, (input) => [null]),
        _throwsAssertionError('`edges` cannot return null values.'));
    expect(() => shortestPaths(1, _identity, (input) => [null]),
        _throwsAssertionError('`edges` cannot return null values.'));
  });

  void _singlePathTest(int from, int to, List<int> expected) {
    test('$from -> $to should be $expected', () {
      expect(
          shortestPath<String, int>(
              from, to, _identity, (input) => graph[input] ?? []),
          expected);
    });
  }

  void _pathsTest(
      int from, Map<String, List<int>> expected, List<int> nullPaths) {
    test('paths from $from', () {
      final result = shortestPaths<String, int>(
          from, _identity, (input) => graph[input] ?? []);
      expect(result, expected);
    });

    for (var entry in expected.entries) {
      _singlePathTest(from, int.parse(entry.key), entry.value);
    }

    for (var entry in nullPaths) {
      _singlePathTest(from, entry, null);
    }
  }

  _pathsTest(1, {
    '5': [5],
    '3': [2, 3],
    '8': [5, 8],
    '1': [],
    '2': [2],
    '4': [2, 3, 4],
  }, [
    6,
    7,
  ]);

  _pathsTest(6, {
    '7': [7],
    '6': [],
  }, [
    1,
  ]);
  _pathsTest(7, {'7': []}, [1, 6]);

  _pathsTest(42, {'42': []}, [1, 6]);

  _singlePathTest(1, null, null);
}
