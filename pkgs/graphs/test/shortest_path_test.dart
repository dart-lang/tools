// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

import 'utils/utils.dart';

Matcher _throwsAssertionError(messageMatcher) =>
    throwsA(const TypeMatcher<AssertionError>()
        .having((ae) => ae.message, 'message', messageMatcher));

int _xKey(X input) => input.value;

T _identity<T>(T input) => input;

void main() {
  const graph = <int, List<int>>{
    1: [2, 5],
    2: [3],
    3: [4, 5],
    4: [1],
    5: [8],
    6: [7],
  };

  List<int> getValues(int key) => graph[key] ?? [];

  List<X> getXValues(X key) =>
      graph[key.value]?.map((v) => X(v))?.toList() ?? [];

  test('null `start` throws AssertionError', () {
    expect(() => shortestPath(null, 1, _identity, getValues),
        _throwsAssertionError('`start` cannot be null'));
    expect(() => shortestPaths(null, _identity, getValues),
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
    test('$from -> $to should be $expected (mapped)', () {
      expect(
          shortestPath<int, X>(X(from), X(to), _xKey, getXValues)
              ?.map((x) => x.value),
          expected);
    });

    test('$from -> $to should be $expected', () {
      expect(shortestPath<int, int>(from, to, _identity, getValues), expected);
    });
  }

  void _pathsTest(int from, Map<int, List<int>> expected, List<int> nullPaths) {
    test('paths from $from (mapped)', () {
      final result = shortestPaths<int, X>(X(from), _xKey, getXValues)
          .map((k, v) => MapEntry(k, v.map((x) => x.value).toList()));
      expect(result, expected);
    });

    test('paths from $from', () {
      final result = shortestPaths<int, int>(from, _identity, getValues);
      expect(result, expected);
    });

    for (var entry in expected.entries) {
      _singlePathTest(from, entry.key, entry.value);
    }

    for (var entry in nullPaths) {
      _singlePathTest(from, entry, null);
    }
  }

  _pathsTest(1, {
    5: [5],
    3: [2, 3],
    8: [5, 8],
    1: [],
    2: [2],
    4: [2, 3, 4],
  }, [
    6,
    7,
  ]);

  _pathsTest(6, {
    7: [7],
    6: [],
  }, [
    1,
  ]);
  _pathsTest(7, {7: []}, [1, 6]);

  _pathsTest(42, {42: []}, [1, 6]);

  _singlePathTest(1, null, null);
}
