// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// See https://en.wikipedia.org/wiki/Edge_list
// This rquires two classes because Edge equality and hashcode
// take directionality into account or they ignore it
import 'graph_node_edge.dart';

/// A representation of a directed graph.
///
/// Graph is stored as a set of [DirectedEdge].
/// Each edge relates two [Node] objects.
///
/// [nodesNext] can be used as a edges function for directed graphs.
/// It can support undirected graphs by adding reverse direction relationships
/// for each forward relationship, adding two [DirectedEdge] for each.
class DirectedGraphEdgeList<T> {
  final Set<DirectedEdge<T>> edges;

  DirectedGraphEdgeList(this.edges);

  /// Returns the nodes on the _to_ side of an edge _from_ [aNode]
  /// This is essentially the `edges` function for this graph
  Iterable<Node<T>> nodesNext(Node<T> aNode) =>
      edges.map((e) => e.from == aNode ? e.to : null).nonNulls;
}

/// A representation of an undirected graph.
///
/// Graph is stored as a set of [UndirectedEdge].
/// Each edge relates two [Node]
///
/// [nodesNextTo] can be used as a edges function for undirected graphs.
class UndirectedGraphEdgeList<T> {
  final Set<UndirectedEdge<T>> edges;

  UndirectedGraphEdgeList(this.edges);

  /// Returns nodes next to [aNode] in any relationship
  /// This is essentially the `edges` function for this graph
  Iterable<Node<T>> nodesNextTo(Node<T> aNode) => edges
      .map(
        (e) => (e.from == aNode)
            ? e.to
            : (e.to == aNode)
                ? e.from
                : null,
      )
      .nonNulls;
}
