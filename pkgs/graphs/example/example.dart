// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:graphs/graphs.dart';

/// A representation of a directed graph.
///
/// Data is stored on the [Node] class.
class Graph {
  final Map<Node, List<Node>> nodes;

  Graph(this.nodes);
}

class Node {
  final String id;
  final int data;

  Node(this.id, this.data);

  @override
  bool operator ==(Object other) => other is Node && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '<$id -> $data>';
}

void main() {
  final nodeA = Node('A', 1);
  final nodeB = Node('B', 2);
  final nodeC = Node('C', 3);
  final nodeD = Node('D', 4);
  final graph = Graph({
    nodeA: [nodeB, nodeC],
    nodeB: [nodeC, nodeD],
    nodeC: [nodeB, nodeD],
  });

  final components = stronglyConnectedComponents<Node>(
    graph.nodes.keys,
    (node) => graph.nodes[node] ?? [],
  );

  print(components);
}
