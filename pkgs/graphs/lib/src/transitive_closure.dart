// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'cycle_exception.dart';
import 'strongly_connected_components.dart';
import 'topological_sort.dart';

/// Returns a transitive closure of a directed graph provided by [nodes] and
/// [edges].
///
/// The result is a map from [nodes] to the sets of nodes that are transitively
/// reachable through [edges]. No particular ordering is guaranteed.
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
/// Note: this requires that [nodes] and each iterable returned by [edges]
/// contain no duplicate entries.
///
/// By default, this can handle either cyclic or acyclic graphs. If [acyclic] is
/// true, this will run more efficiently but throw a [CycleException] if the
/// graph is cyclical.
Map<T, Set<T>> transitiveClosure<T extends Object>(
  Iterable<T> nodes,
  Iterable<T> Function(T) edges, {
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
  bool acyclic = false,
}) {
  if (!acyclic) {
    return _cyclicTransitiveClosure(
      nodes,
      edges,
      equals: equals,
      hashCode: hashCode,
    );
  }

  final topologicalOrder =
      topologicalSort(nodes, edges, equals: equals, hashCode: hashCode);
  final result = LinkedHashMap<T, Set<T>>(equals: equals, hashCode: hashCode);
  for (final node in topologicalOrder.reversed) {
    final closure = LinkedHashSet<T>(equals: equals, hashCode: hashCode);
    for (var child in edges(node)) {
      closure.add(child);
      closure.addAll(result[child]!);
    }

    result[node] = closure;
  }

  return result;
}

/// Returns the transitive closure of a cyclic graph using [Purdom's algorithm].
///
/// [Purdom's algorithm]: https://algowiki-project.org/en/Purdom%27s_algorithm
///
/// This first computes the strongly connected components of the graph and finds
/// the transitive closure of those before flattening it out into the transitive
/// closure of the entire graph.
Map<T, Set<T>> _cyclicTransitiveClosure<T extends Object>(
  Iterable<T> nodes,
  Iterable<T> Function(T) edges, {
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
}) {
  final components = stronglyConnectedComponents<T>(
    nodes,
    edges,
    equals: equals,
    hashCode: hashCode,
  );
  final nodesToComponents =
      HashMap<T, List<T>>(equals: equals, hashCode: hashCode);
  for (final component in components) {
    for (final node in component) {
      nodesToComponents[node] = component;
    }
  }

  // Because [stronglyConnectedComponents] returns the components in reverse
  // topological order, we can avoid an additional topological sort here.
  // Instead, we directly traverse the component list with the knowledge that
  // once we reach a component, everything reachable from it has already been
  // registered in [result].
  final result = LinkedHashMap<T, Set<T>>(equals: equals, hashCode: hashCode);
  for (final component in components) {
    final closure = LinkedHashSet<T>(equals: equals, hashCode: hashCode);
    if (_componentIncludesCycle(component, edges, equals)) {
      closure.addAll(component);
    }

    // De-duplicate downstream components to avoid adding the same transitive
    // children over and over.
    final downstreamComponents = {
      for (final node in component)
        for (final child in edges(node)) nodesToComponents[child]!
    };
    for (final childComponent in downstreamComponents) {
      if (childComponent == component) continue;

      // This if check is just for efficiency. If [childComponent] has multiple
      // nodes, `result[childComponent.first]` will contain all the nodes in
      // `childComponent` anyway since it's cyclical.
      if (childComponent.length == 1) closure.addAll(childComponent);
      closure.addAll(result[childComponent.first]!);
    }

    for (final node in component) {
      result[node] = closure;
    }
  }
  return result;
}

/// Returns whether the strongly-connected component [component] of a graph
/// defined by [edges] includes a cycle.
bool _componentIncludesCycle<T>(
  List<T> component,
  Iterable<T> Function(T) edges,
  bool Function(T, T)? equals,
) {
  // A strongly-connected component with more than one node always contains a
  // cycle, by definition.
  if (component.length > 1) return true;

  // A component with only a single node only contains a cycle if that node has
  // an edge to itself.
  final node = component.single;
  return edges(node)
      .any((edge) => equals == null ? edge == node : equals(edge, node));
}
