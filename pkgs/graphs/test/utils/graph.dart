/// A representation of a Graph since none is specified in `lib/`.
class Graph {
  final Map<String, List<String>> graph;

  Graph(this.graph);

  String key(String node) => node;
  List<String> children(String node) => graph[node];
  Iterable<String> get allNodes => graph.keys;
}
