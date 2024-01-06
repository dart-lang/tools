// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';
import 'graph_adjacency_list.dart';
import 'graph_node_edge.dart';

void main() {
  final nodeA = Node('A', 1);
  final nodeB = Node('B', 2);
  final nodeC = Node('C', 3);
  final nodeD = Node('D', 4);
  final graph = DirectedGraphAdjacencyList({
    nodeA: [nodeB, nodeC],
    nodeB: [nodeC, nodeD],
    nodeC: [nodeB, nodeD],
  });

  print('In directed graph $nodeC next to ${graph.nodesNext(nodeC)}');

  final components = stronglyConnectedComponents<Node<int>>(
    graph.nodes.keys,
    graph.nodesNext,
  );

  print('Strongly connected components $components');

  print('In undirected graph $nodeC next to ${graph.nodesNextTo(nodeC)}');
}
