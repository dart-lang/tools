// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// See https://en.wikipedia.org/wiki/Edge_list
// This rquires two classes because Edge equality and hashcode
// take directionality into account or they ignore it

/// Generic node where the id is used for identity purposes
class Node<T> {
  final String id;
  final T? data;

  Node(this.id, {this.data});

  @override
  bool operator ==(Object other) => other is Node && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '<$id -> $data>';
}

/// An [Edge] epresents the relationship of two nodes.
class Edge<N, T> {
  final Node<N> from;
  final Node<N> to;
  final T? data;
  Edge(this.from, this.to, {this.data});

  @override
  String toString() {
    if (data == null) {
      return '<$from -> $to>';
    } else {
      return '<$from -> $to : $data>';
    }
  }
}

/// An [Edge] epresents the relationship of two nodes.
/// A [DirectedEdge] treates that relationship as directional
/// equals and hashcode are implemented taking into account direction
class DirectedEdge<N, T> extends Edge<N, T> {
  DirectedEdge(super.from, super.to, {super.data});

  @override
  bool operator ==(Object other) =>
      other is DirectedEdge && other.from == from && other.to == to;

  @override
  int get hashCode {
    final fromHash = from.hashCode;
    final toHash = to.hashCode;
    return '$fromHash:$toHash'.hashCode;
  }
}

/// An [Edge] epresents the relationship of two nodes.
/// An [UndirectedEdge] treates that relationship without direction

/// equals and hashcode are implemented ignoring direction
/// from and to are just names without directional meaning
class UndirectedEdge<N, T> extends Edge<N, T> {
  UndirectedEdge(super.from, super.to, {super.data});

  @override
  bool operator ==(Object other) =>
      other is UndirectedEdge &&
      ((other.from == from && other.to == to) ||
          (other.from == to && other.to == from));

  @override
  int get hashCode {
    final fromHash = from.hashCode;
    final toHash = to.hashCode;
    if (toHash < fromHash) {
      return '$toHash:$fromHash'.hashCode;
    } else {
      return '$fromHash:$toHash'.hashCode;
    }
  }
}
