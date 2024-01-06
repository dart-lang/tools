// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';

import 'graph_edge_list.dart';
import 'graph_node_edge.dart';

/// Uses representation of a directed graph implemented as an edge list.
///
void main() {
  final nodeA = Node('A', data: 1);
  final nodeB = Node('B', data: 2);
  final nodeC = Node('C', data: 3);
  final nodeD = Node('D', data: 4);

  final nodes = <Node<int>>[nodeA, nodeB, nodeC, nodeD];

  final graphDirected = DirectedGraphEdgeList({
    DirectedEdge(nodeA, nodeB, data: 'parent'),
    DirectedEdge(nodeA, nodeC, data: 'parent'),
    DirectedEdge(nodeB, nodeC, data: 'sibling'),
    DirectedEdge(nodeB, nodeD, data: 'parent'),
    DirectedEdge(nodeC, nodeB, data: 'sibling'),
    DirectedEdge<int, void>(nodeC, nodeD),
  });
  print(
    'Directed: $nodeB next to ${graphDirected.nodesNextTo(nodeB)}',
  );

  print(
    'Directed: edges leaving $nodeB : ${graphDirected.edgesNextTo(nodeB)}',
  );

  final components = stronglyConnectedComponents<Node<int>>(
    nodes,
    graphDirected.nodesNextTo,
  );

  print('Strongly connected components $components');

  final graphUndirected = UndirectedGraphEdgeList({
    UndirectedEdge(nodeA, nodeB, data: 'parent'),
    UndirectedEdge(nodeA, nodeC, data: 'parent'),
    UndirectedEdge(nodeB, nodeC, data: 'sibling'),
    UndirectedEdge(nodeB, nodeD, data: 'parent'),
    UndirectedEdge(nodeC, nodeB, data: 'sibling'),
    UndirectedEdge<int, void>(nodeC, nodeD),
  });

  print('Undirected: $nodeB next to ${graphUndirected.nodesAdjacent(nodeB)}');

  print(
    'Unirected: edges leaving $nodeB : ${graphUndirected.edgesAdjacent(nodeB)}',
  );
}
