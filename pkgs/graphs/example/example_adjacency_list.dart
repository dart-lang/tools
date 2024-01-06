// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'graph_adjacency_list.dart';
import 'graph_node_edge.dart';

/// Uses representation of a directed graph implemented as an adjacency list.
///
void main() {
  final nodeA = Node('A', data: 1);
  final nodeB = Node('B', data: 2);
  final nodeC = Node('C', data: 3);
  final nodeD = Node('D', data: 4);
  final graph = DirectedGraphAdjacencyList({
    nodeA: {nodeB, nodeC},
    nodeB: {nodeC, nodeD},
    nodeC: {nodeB, nodeD},
  });

  print('In directed graph $nodeC next to ${graph.nodesNextTo(nodeC)}');

  final components = stronglyConnectedComponents<Node<int>>(
    graph.nodes.keys,
    graph.nodesNextTo,
  );

  print('Strongly connected components $components');

  print('In undirected graph $nodeC next to ${graph.nodesAdjacent(nodeC)}');
}
