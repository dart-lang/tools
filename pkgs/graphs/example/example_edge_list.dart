// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';

import 'graph_edge_list.dart';
import 'graph_node_edge.dart';

/// A representation of a directed graph.
///

void main() {
  final nodeA = Node('A', 1);
  final nodeB = Node('B', 2);
  final nodeC = Node('C', 3);
  final nodeD = Node('D', 4);

  final nodes = <Node<int>>[nodeA, nodeB, nodeC, nodeD];

  final graphDirected = DirectedGraphEdgeList({
    DirectedEdge(nodeA, nodeB),
    DirectedEdge(nodeA, nodeC),
    DirectedEdge(nodeB, nodeC),
    DirectedEdge(nodeB, nodeD),
    DirectedEdge(nodeC, nodeB),
    DirectedEdge(nodeC, nodeD),
  });
  print(
    'In directed graph $nodeC next to ${graphDirected.nodesNext(nodeC)}',
  );

  final components = stronglyConnectedComponents<Node<int>>(
    nodes,
    graphDirected.nodesNext,
  );

  print('Strongly connected components $components');

  final graphUndirected = UndirectedGraphEdgeList({
    UndirectedEdge(nodeA, nodeB),
    UndirectedEdge(nodeA, nodeC),
    UndirectedEdge(nodeB, nodeC),
    UndirectedEdge(nodeB, nodeD),
    UndirectedEdge(nodeC, nodeB),
    UndirectedEdge(nodeC, nodeD),
  });

  print(
    'In undirected graph $nodeC next to ${graphUndirected.nodesNextTo(nodeC)}',
  );
}
