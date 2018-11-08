// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

/// Returns the shortest path from [start] to [target] given the directed
/// edges of a graph provided by [edges].
///
/// If [start] `==` [target], an empty [List] is returned and [edges] is never
/// called.
///
/// [V] is the type of values in the graph nodes. [K] must be a type suitable
/// for using as a Map or Set key, and [key] must provide a consistent key for
/// every node.
///
/// [start], [target] and all values returned by [edges] must not be `null`.
/// If asserts are enabled, an [AssertionError] is raised if these conditions
/// are not met. If asserts are not enabled, violations result in undefined
/// behavior.
List<V> shortestPath<K, V>(
        V start, V target, K Function(V) key, Iterable<V> Function(V) edges) =>
    _shortestPaths(start, key, edges, target)[key(target)];

/// Returns a [Map] of the shortest paths from [start] to all of the nodes in
/// the directed graph defined by [edges].
///
/// All return values will contain the key [start] with an empty [List] value.
///
/// [V] is the type of values in the graph nodes. [K] must be a type suitable
/// for using as a Map or Set key, and [key] must provide a consistent key for
/// every node.
///
/// [start] and all values returned by [edges] must not be `null`.
/// If asserts are enabled, an [AssertionError] is raised if these conditions
/// are not met. If asserts are not enabled, violations result in undefined
/// behavior.
Map<K, List<V>> shortestPaths<K, V>(
        V start, K Function(V) key, Iterable<V> Function(V) edges) =>
    _shortestPaths(start, key, edges);

Map<K, List<V>> _shortestPaths<K, V>(
    V start, K Function(V) key, Iterable<V> Function(V) edges,
    [V target]) {
  assert(start != null, '`start` cannot be null');
  assert(key != null, '`key` cannot be null`.');
  assert(edges != null, '`edges` cannot be null');

  final distances = HashMap<K, List<V>>();
  distances[key(start)] = [];

  if (target != null && key(start) == key(target)) {
    return distances;
  }

  final toVisit = ListQueue<V>()..add(start);

  List<V> bestOption;

  while (toVisit.isNotEmpty) {
    final current = toVisit.removeFirst();
    final distanceToCurrent = distances[key(current)];

    if (bestOption != null && distanceToCurrent.length >= bestOption.length) {
      // Skip any existing `toVisit` items that have no chance of being
      // better than bestOption (if it exists)
      continue;
    }

    for (var edge in edges(current)) {
      assert(edge != null, '`edges` cannot return null values.');
      final existingPath = distances[key(edge)];

      if (existingPath == null ||
          existingPath.length > (distanceToCurrent.length + 1)) {
        final newOption = distanceToCurrent.followedBy(<V>[edge]).toList();

        if (target != null && key(edge) == key(target)) {
          assert(bestOption == null || bestOption.length > newOption.length);
          bestOption = newOption;
        }

        distances[key(edge)] = newOption;
        if (bestOption == null || bestOption.length > newOption.length) {
          // Only add a node to visit if it might be a better path to the
          // target node
          toVisit.add(edge);
        }
      }
    }
  }

  return distances;
}
