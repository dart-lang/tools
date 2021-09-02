// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

import 'utils/utils.dart';

void main() {
  group('sorts a graph', () {
    test('with no nodes', () {
      expect(_topologicalSort({}), isEmpty);
    });

    test('with only one node', () {
      expect(_topologicalSort({1: []}), equals([1]));
    });

    test('with no edges', () {
      expect(_topologicalSort({1: [], 2: [], 3: [], 4: []}),
          unorderedEquals([1, 2, 3, 4]));
    });

    test('with single edges', () {
      expect(
          _topologicalSort({
            1: [2],
            2: [3],
            3: [4],
            4: []
          }),
          equals([1, 2, 3, 4]));
    });

    test('with many edges from one node', () {
      var result = _topologicalSort({
        1: [2, 3, 4],
        2: [],
        3: [],
        4: []
      });
      expect(result.indexOf(1), lessThan(result.indexOf(2)));
      expect(result.indexOf(1), lessThan(result.indexOf(3)));
      expect(result.indexOf(1), lessThan(result.indexOf(4)));
    });

    test('with transitive edges', () {
      var result = _topologicalSort({
        1: [2, 4],
        2: [],
        3: [],
        4: [3]
      });
      expect(result.indexOf(1), lessThan(result.indexOf(2)));
      expect(result.indexOf(1), lessThan(result.indexOf(3)));
      expect(result.indexOf(1), lessThan(result.indexOf(4)));
      expect(result.indexOf(4), lessThan(result.indexOf(3)));
    });

    test('with diamond edges', () {
      var result = _topologicalSort({
        1: [2, 3],
        2: [4],
        3: [4],
        4: []
      });
      expect(result.indexOf(1), lessThan(result.indexOf(2)));
      expect(result.indexOf(1), lessThan(result.indexOf(3)));
      expect(result.indexOf(1), lessThan(result.indexOf(4)));
      expect(result.indexOf(2), lessThan(result.indexOf(4)));
      expect(result.indexOf(3), lessThan(result.indexOf(4)));
    });
  });

  test('respects custom equality and hash functions', () {
    expect(
        _topologicalSort<int>({
          0: [2],
          3: [4],
          5: [6],
          7: []
        },
            equals: (i, j) => (i ~/ 2) == (j ~/ 2),
            hashCode: (i) => (i ~/ 2).hashCode),
        equals([
          0,
          anyOf([2, 3]),
          anyOf([4, 5]),
          anyOf([6, 7])
        ]));
  });

  group('throws a CycleException for a graph with', () {
    test('a one-node cycle', () {
      expect(
          () => _topologicalSort({
                1: [1]
              }),
          throwsCycleException([1]));
    });

    test('a multi-node cycle', () {
      expect(
          () => _topologicalSort({
                1: [2],
                2: [3],
                3: [4],
                4: [1]
              }),
          throwsCycleException([1, 2, 3, 4]));
    });
  });
}

/// Runs a topological sort on a graph represented a map from keys to edges.
List<T> _topologicalSort<T>(Map<T, List<T>> graph,
    {bool Function(T, T)? equals, int Function(T)? hashCode}) {
  if (equals != null) {
    graph = LinkedHashMap(equals: equals, hashCode: hashCode)..addAll(graph);
  }
  return topologicalSort(graph.keys, (node) {
    expect(graph, contains(node));
    return graph[node]!;
  }, equals: equals, hashCode: hashCode);
}
