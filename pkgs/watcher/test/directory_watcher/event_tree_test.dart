// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:watcher/src/directory_watcher/event_tree.dart';
import 'package:watcher/src/paths.dart';

final separator = Platform.pathSeparator;

void main() {
  group('EventTree', () {
    test('empty event tree is not an event', () {
      expect(EventTree().isSingleEvent, false);
    });

    test('event tree with event at root is an event', () {
      final eventTree = EventTree();
      eventTree.add(RelativePath(''));
      expect(eventTree.isSingleEvent, true);
    });

    test('event tree with event under root has expected single event', () {
      final eventTree = EventTree();
      eventTree.add(RelativePath('a'));
      expect(eventTree.isSingleEvent, false);

      expect(eventTree[PathSegment('a')]!.isSingleEvent, true);
    });

    test('event tree with event deep under root has expected single event', () {
      final eventTree = EventTree();
      eventTree.add(RelativePath('a${separator}b'));
      expect(eventTree.isSingleEvent, false);

      expect(eventTree[PathSegment('a')]!.isSingleEvent, false);
      expect(
          eventTree[PathSegment('a')]![PathSegment('b')]!.isSingleEvent, true);
    });

    test('adding event removes tree under it', () {
      final eventTree = EventTree();
      eventTree.add(RelativePath('a${separator}b'));
      eventTree.add(RelativePath('a'));

      expect(eventTree[PathSegment('a')]![PathSegment('b')], null);
    });

    test("events can't be added under an event", () {
      final eventTree = EventTree();
      eventTree.add(RelativePath('a'));
      eventTree.add(RelativePath('a${separator}b'));

      expect(eventTree[PathSegment('a')]![PathSegment('b')], null);
    });
  });
}
