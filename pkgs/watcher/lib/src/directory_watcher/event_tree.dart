// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../paths.dart';

/// Tree of event paths relative to the watched path.
///
/// If [isSingleEvent] then there is an event at the current path. Because
/// changed directories must be fully polled, events "under" the current path
/// are not useful, and are discarded from the tree.
class EventTree {
  Map<PathSegment, EventTree>? _events;

  EventTree() : _events = {};
  EventTree.singleEvent() : _events = null;

  /// Adds an event at [path].
  ///
  /// If there are already events under [path], that part of the tree has
  /// [isSingleEvent] set and events under it are discarded.
  ///
  /// If there is already an event for a parent of [path], it is discarded
  /// instead of added.
  void add(RelativePath path) {
    final segments = path.segments;
    var current = this;

    for (final segment in segments) {
      final events = current._events;
      if (events == null) {
        // There is already an event for a parent of [path], discard the
        // new event.
        return;
      }
      // Add to the tree for [segment].
      current = events.putIfAbsent(segment, EventTree.new);
    }

    // Mark [path] as a [singleEvent] and discard any events under it.
    current._events = null;
  }

  /// Whether this event tree is actually a single event.
  ///
  /// There can be no events under it; [entries] will throw.
  bool get isSingleEvent => _events == null;

  /// Returns the event tree at [segment], or `null` if there is none.
  EventTree? operator [](PathSegment segment) => _events?[segment];

  /// Returns child event trees by path segment.
  ///
  /// Throws if [isSingleEvent].
  Iterable<MapEntry<PathSegment, EventTree>> get entries => _events!.entries;

  @override
  String toString() => _events == null ? 'event' : '$_events';
}
