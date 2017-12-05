// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A representation of a Graph since none is specified in `lib/`.
class Graph {
  final Map<String, List<String>> graph;

  Graph(this.graph);

  String key(String node) => node;
  List<String> children(String node) => graph[node];
  Iterable<String> get allNodes => graph.keys;
}

/// A representation of a Graph where keys can asynchronously be resolved to
/// real values or to children.
class AsyncGraph {
  final Map<String, List<String>> graph;

  AsyncGraph(this.graph);

  Future<String> readNode(String node) async => node;
  Future<Iterable<String>> children(String key, String node) async =>
      graph[key];
}
