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
/// [start], [target] and all values returned by [edges] must not be `null`.
/// If asserts are enabled, an [AssertionError] is raised if these conditions
/// are not met. If asserts are not enabled, violations result in undefined
/// behavior.
///
/// If [equals] is provided, it is used to compare nodes in the graph. If
/// [equals] is omitted, the node's own [Object.==] is used instead.
///
/// Similarly, if [hashCode] is provided, it is used to produce a hash value
/// for nodes to efficiently calculate the return value. If it is omitted, the
/// key's own [Object.hashCode] is used.
///
/// If you supply one of [equals] or [hashCode], you should generally also to
/// supply the other.
List<T> shortestPath<T>(
  T start,
  T target,
  Iterable<T> Function(T) edges, {
  bool Function(T, T) equals,
  int Function(T) hashCode,
}) =>
    _shortestPaths<T>(
      start,
      edges,
      target: target,
      equals: equals,
      hashCode: hashCode,
    )[target];

/// Returns a [Map] of the shortest paths from [start] to all of the nodes in
/// the directed graph defined by [edges].
///
/// All return values will contain the key [start] with an empty [List] value.
///
/// [start] and all values returned by [edges] must not be `null`.
/// If asserts are enabled, an [AssertionError] is raised if these conditions
/// are not met. If asserts are not enabled, violations result in undefined
/// behavior.
///
/// If [equals] is provided, it is used to compare nodes in the graph. If
/// [equals] is omitted, the node's own [Object.==] is used instead.
///
/// Similarly, if [hashCode] is provided, it is used to produce a hash value
/// for nodes to efficiently calculate the return value. If it is omitted, the
/// key's own [Object.hashCode] is used.
///
/// If you supply one of [equals] or [hashCode], you should generally also to
/// supply the other.
Map<T, List<T>> shortestPaths<T>(
  T start,
  Iterable<T> Function(T) edges, {
  bool Function(T, T) equals,
  int Function(T) hashCode,
}) =>
    _shortestPaths<T>(
      start,
      edges,
      equals: equals,
      hashCode: hashCode,
    );

Map<T, List<T>> _shortestPaths<T>(
  T start,
  Iterable<T> Function(T) edges, {
  T target,
  bool Function(T, T) equals,
  int Function(T) hashCode,
}) {
  assert(start != null, '`start` cannot be null');
  assert(edges != null, '`edges` cannot be null');

  final distances = HashMap<T, List<T>>(equals: equals, hashCode: hashCode);
  distances[start] = List(0);

  equals ??= _defaultEquals;
  if (equals(start, target)) {
    return distances;
  }

  final toVisit = ListQueue<T>()..add(start);

  List<T> bestOption;

  while (toVisit.isNotEmpty) {
    final current = toVisit.removeFirst();
    final currentPath = distances[current];
    final currentPathLength = currentPath.length;

    if (bestOption != null && (currentPathLength + 1) >= bestOption.length) {
      // Skip any existing `toVisit` items that have no chance of being
      // better than bestOption (if it exists)
      continue;
    }

    for (var edge in edges(current)) {
      assert(edge != null, '`edges` cannot return null values.');
      final existingPath = distances[edge];

      assert(existingPath == null ||
          existingPath.length <= (currentPathLength + 1));

      if (existingPath == null) {
        final newOption = List<T>(currentPathLength + 1)
          ..setRange(0, currentPathLength, currentPath)
          ..[currentPathLength] = edge;

        if (equals(edge, target)) {
          assert(bestOption == null || bestOption.length > newOption.length);
          bestOption = newOption;
        }

        distances[edge] = newOption;
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

bool _defaultEquals(Object a, Object b) => a == b;
