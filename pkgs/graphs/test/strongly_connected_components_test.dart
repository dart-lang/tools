// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:graphs/graphs.dart';

import 'utils/graph.dart';

void main() {
  group('strongly connected components', () {
    /// Run [stronglyConnectedComponents] on [g].
    List<List<String>> components(Map<String, List<String>> g) {
      final graph = Graph(g);
      return stronglyConnectedComponents(
          graph.allNodes, graph.key, graph.children);
    }

    test('empty result for empty graph', () {
      var result = components({});
      expect(result, isEmpty);
    });

    test('single item for single node', () {
      var result = components({'a': []});
      expect(result, [
        ['a']
      ]);
    });

    test('handles non-cycles', () {
      var result = components({
        'a': ['b'],
        'b': ['c'],
        'c': []
      });
      expect(result, [
        ['c'],
        ['b'],
        ['a']
      ]);
    });

    test('handles entire graph as cycle', () {
      var result = components({
        'a': ['b'],
        'b': ['c'],
        'c': ['a']
      });
      expect(result, [allOf(contains('a'), contains('b'), contains('c'))]);
    });

    test('includes the first passed root last in a cycle', () {
      // In cases where this is used to find a topological ordering the first
      // value in nodes should always come last.
      var graph = Graph({
        'a': ['b'],
        'b': ['a']
      });
      var resultFromA =
          stronglyConnectedComponents(['a'], graph.key, graph.children);
      var resultFromB =
          stronglyConnectedComponents(['b'], graph.key, graph.children);
      expect(resultFromA.single.last, 'a');
      expect(resultFromB.single.last, 'b');
    });

    test('handles cycles in the middle', () {
      var result = components({
        'a': ['b', 'c'],
        'b': ['c', 'd'],
        'c': ['b', 'd'],
        'd': [],
      });
      expect(result, [
        ['d'],
        allOf(contains('b'), contains('c')),
        ['a'],
      ]);
    });

    test('handles self cycles', () {
      var result = components({
        'a': ['b'],
        'b': ['b'],
      });
      expect(result, [
        ['b'],
        ['a'],
      ]);
    });

    test('valid topological ordering for disjoint subgraphs', () {
      var result = components({
        'a': ['b', 'c'],
        'b': ['b1', 'b2'],
        'c': ['c1', 'c2'],
        'b1': [],
        'b2': [],
        'c1': [],
        'c2': []
      });

      expect(
          result,
          containsAllInOrder([
            ['c1'],
            ['c'],
            ['a']
          ]));
      expect(
          result,
          containsAllInOrder([
            ['c2'],
            ['c'],
            ['a']
          ]));
      expect(
          result,
          containsAllInOrder([
            ['b1'],
            ['b'],
            ['a']
          ]));
      expect(
          result,
          containsAllInOrder([
            ['b2'],
            ['b'],
            ['a']
          ]));
    });

    test('handles getting null for children', () {
      var result = components({
        'a': ['b'],
        'b': null,
      });
      expect(result, [
        ['b'],
        ['a']
      ]);
    });
  });
}
