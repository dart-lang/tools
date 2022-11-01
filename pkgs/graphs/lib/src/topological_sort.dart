// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:collection/collection.dart' hide stronglyConnectedComponents;

import 'cycle_exception.dart';

/// Returns a topological sort of the nodes of the directed edges of a graph
/// provided by [nodes] and [edges].
///
/// Each element of the returned iterable is guaranteed to appear after all
/// nodes that have edges leading to that node. The result is not guaranteed to
/// be unique, nor is it guaranteed to be stable across releases of this
/// package; however, it will be stable for a given input within a given package
/// version.
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
///
/// If you supply [secondarySort], the resulting list will be sorted by that
/// comparison function as much as possible without violating the topological
/// ordering. Note that even with a secondary sort, the result is _still_ not
/// guaranteed to be unique or stable across releases of this package.
///
/// Note: this requires that [nodes] and each iterable returned by [edges]
/// contain no duplicate entries.
///
/// Throws a [CycleException<T>] if the graph is cyclical.
List<T> topologicalSort<T>(
  Iterable<T> nodes,
  Iterable<T> Function(T) edges, {
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
  Comparator<T>? secondarySort,
}) {
  if (secondarySort != null) {
    return _topologicalSortWithSecondary(
      [...nodes],
      edges,
      secondarySort,
      equals,
      hashCode,
    );
  }

  // https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search
  final result = QueueList<T>();
  final permanentMark = HashSet<T>(equals: equals, hashCode: hashCode);
  final temporaryMark = LinkedHashSet<T>(equals: equals, hashCode: hashCode);
  void visit(T node) {
    if (permanentMark.contains(node)) return;
    if (temporaryMark.contains(node)) {
      throw CycleException(temporaryMark);
    }

    temporaryMark.add(node);
    for (var child in edges(node)) {
      visit(child);
    }
    temporaryMark.remove(node);
    permanentMark.add(node);
    result.addFirst(node);
  }

  for (var node in nodes) {
    visit(node);
  }
  return result;
}

/// An implementation of [topologicalSort] with a secondary comparison function.
List<T> _topologicalSortWithSecondary<T>(
  List<T> nodes,
  Iterable<T> Function(T) edges,
  Comparator<T> comparator,
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
) {
  // https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm,
  // modified to sort the nodes to traverse. Also documented in
  // https://www.algotree.org/algorithms/tree_graph_traversal/lexical_topological_sort_c++/

  // For each node, the number of incoming edges it has that we haven't yet
  // traversed.
  final incomingEdges = HashMap<T, int>(equals: equals, hashCode: hashCode);
  for (var node in nodes) {
    for (var child in edges(node)) {
      incomingEdges[child] = (incomingEdges[child] ?? 0) + 1;
    }
  }

  // A priority queue of nodes that have no remaining incoming edges.
  final nodesToTraverse = PriorityQueue<T>(comparator);
  for (var node in nodes) {
    if (!incomingEdges.containsKey(node)) nodesToTraverse.add(node);
  }

  final result = <T>[];
  while (nodesToTraverse.isNotEmpty) {
    final node = nodesToTraverse.removeFirst();
    result.add(node);
    for (var child in edges(node)) {
      var remainingEdges = incomingEdges[child]!;
      remainingEdges--;
      incomingEdges[child] = remainingEdges;
      if (remainingEdges == 0) nodesToTraverse.add(child);
    }
  }

  if (result.length < nodes.length) {
    // This algorithm doesn't automatically produce a cycle list as a side
    // effect of sorting, so to throw the appropriate [CycleException] we just
    // call the normal [topologicalSort] with a view of this graph that only
    // includes nodes that still have edges.
    bool nodeIsInCycle(T node) {
      final edges = incomingEdges[node];
      return edges != null && edges > 0;
    }

    topologicalSort<T>(
      nodes.where(nodeIsInCycle),
      edges,
      equals: equals,
      hashCode: hashCode,
    );
    assert(false, 'topologicalSort() should throw if the graph has a cycle');
  }

  return result;
}
