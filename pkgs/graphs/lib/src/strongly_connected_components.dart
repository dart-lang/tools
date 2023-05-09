// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:math' show min;

/// Finds the strongly connected components of a directed graph using Tarjan's
/// algorithm.
///
/// The result will be a valid reverse topological order ordering of the
/// strongly connected components. Components further from a root will appear in
/// the result before the components which they are connected to.
///
/// Nodes within a strongly connected component have no ordering guarantees,
/// except that if the first value in [nodes] is a valid root, and is contained
/// in a cycle, it will be the last element of that cycle.
///
/// [nodes] must contain at least a root of every tree in the graph if there are
/// disjoint subgraphs but it may contain all nodes in the graph if the roots
/// are not known.
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
List<List<T>> stronglyConnectedComponents<T extends Object>(
  Iterable<T> nodes,
  Iterable<T> Function(T) edges, {
  bool Function(T, T)? equals,
  int Function(T)? hashCode,
}) {
  final result = <List<T>>[];
  final lowLinks = HashMap<T, int>(equals: equals, hashCode: hashCode);
  final indexes = HashMap<T, int>(equals: equals, hashCode: hashCode);
  final onStack = HashSet<T>(equals: equals, hashCode: hashCode);

  final nonNullEquals = equals ?? _defaultEquals;

  var index = 0;
  final lastVisited = Queue<T>();

  final stack = [for (final node in nodes) _StackState(node)];
  outer:
  while (stack.isNotEmpty) {
    final state = stack.removeLast();
    final node = state.node;
    var iterator = state.iterator;

    int lowLink;
    if (iterator == null) {
      if (indexes.containsKey(node)) continue;
      indexes[node] = index;
      lowLink = lowLinks[node] = index;
      index++;
      iterator = edges(node).iterator;

      // Nodes with no edges are always in their own component.
      if (!iterator.moveNext()) {
        result.add([node]);
        continue;
      }

      lastVisited.addLast(node);
      onStack.add(node);
    } else {
      lowLink = min(lowLinks[node]!, lowLinks[iterator.current]!);
    }

    do {
      final next = iterator.current;
      if (!indexes.containsKey(next)) {
        stack.add(_StackState(node, iterator));
        stack.add(_StackState(next));
        continue outer;
      } else if (onStack.contains(next)) {
        lowLink = lowLinks[node] = min(lowLink, indexes[next]!);
      }
    } while (iterator.moveNext());

    if (lowLink == indexes[node]) {
      final component = <T>[];
      T next;
      do {
        next = lastVisited.removeLast();
        onStack.remove(next);
        component.add(next);
      } while (!nonNullEquals(next, node));
      result.add(component);
    }
  }

  return result;
}

/// The state of a pass on a single node in Tarjan's Algorithm.
///
/// This is used to perform the algorithm with an explicit stack rather than
/// recursively, to avoid stack overflow errors for very large graphs.
class _StackState<T> {
  /// The node being inspected.
  final T node;

  /// The iterator traversing [node]'s edges.
  ///
  /// This is null if the node hasn't yet begun being traversed.
  final Iterator<T>? iterator;

  _StackState(this.node, [this.iterator]);
}

bool _defaultEquals(Object a, Object b) => a == b;
