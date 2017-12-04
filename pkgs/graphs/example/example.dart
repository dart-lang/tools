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
  var nodeA = new Node('A', 1);
  var nodeB = new Node('B', 2);
  var nodeC = new Node('C', 3);
  var nodeD = new Node('D', 4);
  var graph = new Graph({
    nodeA: [nodeB, nodeC],
    nodeB: [nodeC, nodeD],
    nodeC: [nodeB, nodeD]
  });

  var components = stronglyConnectedComponents<Node, Node>(
      graph.nodes.keys, (node) => node, (node) => graph.nodes[node]);

  print(components);
}
