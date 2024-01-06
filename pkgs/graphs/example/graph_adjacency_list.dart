// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// See https://en.wikipedia.org/wiki/Adjacency_list
// This only requires one class because we only do Node comparisons
import 'graph_node_edge.dart';

/// A representation of a directed graph.
///
/// [nodesNextTo] can be used as a edges function for directed graphs.
/// It can support undirected graphs by adding reverse direction relationships
/// for each forward relationship
/// or by using the, inefficient, bi-directional edge walker [nodesAdjacent]
///
/// Data is stored on the [Node] class.
class DirectedGraphAdjacencyList<T> {
  /// a Set because this model only supports one directed from-to per pair
  final Map<Node<T>, Set<Node<T>>> nodes;

  DirectedGraphAdjacencyList(this.nodes);

  /// Returns the nodes on the _to_ side of an edge _from_ [aNode].
  /// This is a directed `edges` function for this graph
  Iterable<Node<T>> nodesNextTo(Node<T> aNode) => nodes[aNode] ?? [];

  /// Returns the nodes next to [aNode] on either side of a _from_ or _to_
  /// This is an undirected `edges` function for this graph
  Iterable<Node<T>> nodesAdjacent(Node<T> aNode) {
    final results = nodesNextTo(aNode).toSet();

    results.addAll(
      nodes.keys
          .map((key) => nodes[key]!.contains(aNode) ? key : null)
          .nonNulls,
    );

    return results;
  }
}
