[![CI](https://github.com/dart-lang/tools/actions/workflows/graphs.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/graphs.yaml)
[![pub package](https://img.shields.io/pub/v/graphs.svg)](https://pub.dev/packages/graphs)
[![package publisher](https://img.shields.io/pub/publisher/graphs.svg)](https://pub.dev/packages/graphs/publisher)

Graph algorithms that do not specify a particular approach for representing a
Graph.

Each algorithm is a top level function which takes callback arguments that
provide the mechanism for traversing the graph. For example, two common
approaches for representing a graph:

```dart
class AdjacencyListGraph<T> {
  Map<T, List<T>> nodes;
  // ...
}
```

```dart
class TreeGraph<T> {
  Node<T> root;
  // ...
}
class Node<T> {
  List<Node<T>> edges;
  T value;
}
```

Any representation can be adapted to the callback arguments.

- Algorithms which need to traverse the graph take an `edges` callback which
  provides the immediate neighbors of a given node.
- Algorithms which need to associate unique data with each node in the graph
  allow passing `equals` and/or `hashCode` callbacks if the unique data type
  does not correctly or efficiently implement `operator==` or `get hashCode`.


Algorithms that support graphs which are resolved asynchronously will have
similar callbacks which return `FutureOr`.

```dart
import 'package:graphs/graphs.dart';

void sendMessage() {
  final network = AdjacencyListGraph();
  // ...
  final route = shortestPath(
      sender, receiver, (node) => network.nodes[node] ?? const []);
}

void resolveBuildOrder() {
  final dependencies = TreeGraph();
  // ...
  final buildOrder = topologicalSort([dependencies.root], (node) => node.edges);
}
```
