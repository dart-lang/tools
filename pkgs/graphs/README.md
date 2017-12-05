# [![Build Status](https://travis-ci.org/dart-lang/graphs.svg?branch=master)](https://travis-ci.org/dart-lang/graphs)

Graph algorithms which do not specify a particular approach for representing a
Graph.

Functions in this package will take arguments that provide the mechanism for
traversing the graph. For example two common approaches for representing a
graph:

```dart
class Graph {
  Map<Node, List<Node>> nodes;
}
class Node {
  // Interesting data
}
```

```dart
class Graph {
  Node root;
}
class Node {
  List<Node> children;
  // Interesting data
}
```

Any representation can be adapted to the needs of the algorithm:

- Some algorithms need to associate data with each node in the graph and it will
  be keyed by some type `K` that must work as a key in a `HashMap`. If nodes
  implement `hashCode` and `==`, or if they are known to have one instance per
  logical node such that instance equality is sufficient, then the node can be
  passed through directly.
  - `(node) => node`
  - `(node) => node.id`
- Algorithms which need to traverse the graph take a `children` function which
  provides the reachable nodes.
  - `(node) => graph[node]`
  - `(node) => node.children`

Graphs which are resolved asynchronously will have similar functions which
return `FutureOr`.
