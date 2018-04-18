// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

final _empty = new Future<Null>.value(null);

/// Finds and returns every node in a graph who's nodes and edges are
/// asynchronously resolved.
///
/// Cycles are allowed. If this is an undirected graph the [children] function
/// may be symmetric. In this case the [roots] may be any node in each connected
/// graph.
///
/// [V] is the type of values in the graph nodes. [K] must be a type suitable
/// for using as a Map or Set key. [children] should return the next reachable
/// nodes.
///
/// There are no ordering guarantees. This is useful for ensuring some work is
/// performed at every node in an asynchronous graph, but does not give
/// guarantees that the work is done in topological order.
///
/// If [readNode] returns null for any key it will be ignored from the rest of
/// the graph. If missing nodes are important they should be tracked within the
/// [readNode] callback.
Stream<V> crawlAsync<K, V>(Iterable<K> roots, FutureOr<V> Function(K) readNode,
    FutureOr<Iterable<K>> Function(K, V) children) {
  final crawl = new _CrawlAsync(roots, readNode, children)..run();
  return crawl.result.stream;
}

class _CrawlAsync<K, V> {
  final result = new StreamController<V>();

  final FutureOr<V> Function(K) readNode;
  final FutureOr<Iterable<K>> Function(K, V) children;
  final Iterable<K> roots;

  final _seen = new Set<K>();

  _CrawlAsync(this.roots, this.readNode, this.children);

  /// Add all nodes in the graph to [result] and return a Future which fires
  /// after all nodes have been seen.
  Future<Null> run() async {
    await Future.wait(roots.map(_visit));
    await result.close();
  }

  /// Resolve the node at [key] and output it, then start crawling all of it's
  /// children.
  Future<Null> _crawlFrom(K key) async {
    var value = await readNode(key);
    if (value == null) return;
    result.add(value);
    var next = await children(key, value) ?? const [];
    await Future.wait(next.map(_visit));
  }

  /// Synchronously record that [key] is being handled then start work on the
  /// node for [key].
  ///
  /// The returned Future will complete only after the work for [key] and all
  /// transitively reachable nodes has either been finished, or will be finished
  /// by some other Future in [_seen].
  Future<Null> _visit(K key) {
    if (_seen.contains(key)) return _empty;
    _seen.add(key);
    return _crawlFrom(key);
  }
}
