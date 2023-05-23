// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:graphs/graphs.dart';
import 'package:test/test.dart';

import 'utils/utils.dart';

void main() {
  group('for an acyclic graph', () {
    for (final acyclic in [true, false]) {
      group('with acyclic: $acyclic', () {
        group('returns the transitive closure for a graph', () {
          test('with no nodes', () {
            expect(_transitiveClosure<int>({}, acyclic: acyclic), isEmpty);
          });

          test('with only one node', () {
            expect(
              _transitiveClosure<int>({1: []}, acyclic: acyclic),
              equals({1: <int>{}}),
            );
          });

          test('with no edges', () {
            expect(
              _transitiveClosure<int>(
                {1: [], 2: [], 3: [], 4: []},
                acyclic: acyclic,
              ),
              equals(<int, Set<int>>{1: {}, 2: {}, 3: {}, 4: {}}),
            );
          });

          test('with single edges', () {
            expect(
              _transitiveClosure<int>(
                {
                  1: [2],
                  2: [3],
                  3: [4],
                  4: []
                },
                acyclic: acyclic,
              ),
              equals({
                1: {2, 3, 4},
                2: {3, 4},
                3: {4},
                4: <int>{}
              }),
            );
          });

          test('with many edges from one node', () {
            expect(
              _transitiveClosure<int>(
                {
                  1: [2, 3, 4],
                  2: [],
                  3: [],
                  4: []
                },
                acyclic: acyclic,
              ),
              equals(<int, Set<int>>{
                1: {2, 3, 4},
                2: {},
                3: {},
                4: {}
              }),
            );
          });

          test('with transitive edges', () {
            expect(
              _transitiveClosure<int>(
                {
                  1: [2, 4],
                  2: [],
                  3: [],
                  4: [3]
                },
                acyclic: acyclic,
              ),
              equals(<int, Set<int>>{
                1: {2, 3, 4},
                2: {},
                3: {},
                4: {3}
              }),
            );
          });

          test('with diamond edges', () {
            expect(
              _transitiveClosure<int>(
                {
                  1: [2, 3],
                  2: [4],
                  3: [4],
                  4: []
                },
                acyclic: acyclic,
              ),
              equals(<int, Set<int>>{
                1: {2, 3, 4},
                2: {4},
                3: {4},
                4: {}
              }),
            );
          });

          test('with disjoint subgraphs', () {
            expect(
              _transitiveClosure<int>(
                {
                  1: [2],
                  2: [3],
                  3: [],
                  4: [5],
                  5: [6],
                  6: [],
                },
                acyclic: acyclic,
              ),
              equals(<int, Set<int>>{
                1: {2, 3},
                2: {3},
                3: {},
                4: {5, 6},
                5: {6},
                6: {},
              }),
            );
          });
        });

        test('respects custom equality and hash functions', () {
          final result = _transitiveClosure<int>(
            {
              0: [2],
              3: [4],
              5: [6],
              7: []
            },
            equals: (i, j) => (i ~/ 2) == (j ~/ 2),
            hashCode: (i) => (i ~/ 2).hashCode,
          );

          expect(
            result.keys,
            unorderedMatches([
              0,
              anyOf([2, 3]),
              anyOf([4, 5]),
              anyOf([6, 7])
            ]),
          );
          expect(
            result[0],
            equals({
              anyOf([2, 3]),
              anyOf([4, 5]),
              anyOf([6, 7])
            }),
          );
          expect(
            result[2],
            equals({
              anyOf([4, 5]),
              anyOf([6, 7])
            }),
          );
          expect(
            result[4],
            equals({
              anyOf([6, 7])
            }),
          );
          expect(result[6], isEmpty);
        });
      });
    }
  });

  group('for a cyclic graph', () {
    group('with acyclic: true throws a CycleException for a graph with', () {
      test('a one-node cycle', () {
        expect(
          () => _transitiveClosure<int>(
            {
              1: [1]
            },
            acyclic: true,
          ),
          throwsCycleException([1]),
        );
      });

      test('a multi-node cycle', () {
        expect(
          () => _transitiveClosure<int>(
            {
              1: [2],
              2: [3],
              3: [4],
              4: [1]
            },
            acyclic: true,
          ),
          throwsCycleException([4, 1, 2, 3]),
        );
      });
    });

    group('returns the transitive closure for a graph', () {
      test('with a single one-node component', () {
        expect(
          _transitiveClosure<int>({
            1: [1]
          }),
          equals({
            1: {1}
          }),
        );
      });

      test('with a single multi-node component', () {
        expect(
          _transitiveClosure<int>({
            1: [2],
            2: [3],
            3: [4],
            4: [1]
          }),
          equals({
            1: {1, 2, 3, 4},
            2: {1, 2, 3, 4},
            3: {1, 2, 3, 4},
            4: {1, 2, 3, 4}
          }),
        );
      });

      test('with a series of multi-node components', () {
        expect(
          _transitiveClosure<int>({
            1: [2],
            2: [1, 3],
            3: [4],
            4: [3, 5],
            5: [6],
            6: [5, 7],
            7: [8],
            8: [7],
          }),
          equals({
            1: {1, 2, 3, 4, 5, 6, 7, 8},
            2: {1, 2, 3, 4, 5, 6, 7, 8},
            3: {3, 4, 5, 6, 7, 8},
            4: {3, 4, 5, 6, 7, 8},
            5: {5, 6, 7, 8},
            6: {5, 6, 7, 8},
            7: {7, 8},
            8: {7, 8}
          }),
        );
      });

      test('with a diamond of multi-node components', () {
        expect(
          _transitiveClosure<int>({
            1: [2],
            2: [1, 3, 5],
            3: [4],
            4: [3, 7],
            5: [6],
            6: [5, 7],
            7: [8],
            8: [7],
          }),
          equals({
            1: {1, 2, 3, 4, 5, 6, 7, 8},
            2: {1, 2, 3, 4, 5, 6, 7, 8},
            3: {3, 4, 7, 8},
            4: {3, 4, 7, 8},
            5: {5, 6, 7, 8},
            6: {5, 6, 7, 8},
            7: {7, 8},
            8: {7, 8}
          }),
        );
      });

      test('mixed single- and multi-node components', () {
        expect(
          _transitiveClosure<int>({
            1: [2],
            2: [1, 3],
            3: [4],
            4: [5],
            5: [4, 6],
            6: [7],
            7: [8],
            8: [7],
          }),
          equals({
            1: {1, 2, 3, 4, 5, 6, 7, 8},
            2: {1, 2, 3, 4, 5, 6, 7, 8},
            3: {4, 5, 6, 7, 8},
            4: {4, 5, 6, 7, 8},
            5: {4, 5, 6, 7, 8},
            6: {7, 8},
            7: {7, 8},
            8: {7, 8}
          }),
        );
      });
    });
  });
}

/// Returns the transitive closure of a graph represented a map from keys to
/// edges.
Map<T, Set<T>> _transitiveClosure<T extends Object>(
  Map<T, List<T>> graph, {
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
  bool acyclic = false,
}) {
  assert((equals == null) == (hashCode == null));
  if (equals != null) {
    graph = LinkedHashMap(equals: equals, hashCode: hashCode)..addAll(graph);
  }
  return transitiveClosure(
    graph.keys,
    (node) {
      expect(graph, contains(node));
      return graph[node]!;
    },
    equals: equals,
    hashCode: hashCode,
    acyclic: acyclic,
  );
}
