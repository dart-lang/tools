// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Extension type replacing [FileSystemEvent] for `package:watcher` internal
/// use.
///
/// The [FileSystemDeleteEvent] subclass of [FileSystemEvent] does something
/// surprising for `isDirectory`: it always returns `false`. The constructor
/// accepts a boolean called `isDirectory` but discards it.
///
/// So, this extension type hides `isDirectory` and instead provides an
/// [EventType] enum with the seven types of event actually used.
extension type Event(FileSystemEvent event) {
  /// See [FileSystemEvent.path].
  String get path => event.path;

  EventType get type {
    switch (event.type) {
      case FileSystemEvent.create:
        return event.isDirectory
            ? EventType.createDirectory
            : EventType.createFile;
      case FileSystemEvent.delete:
        return EventType.delete;
      case FileSystemEvent.modify:
        return event.isDirectory
            ? EventType.modifyDirectory
            : EventType.modifyFile;
      case FileSystemEvent.move:
        return event.isDirectory ? EventType.moveDirectory : EventType.moveFile;
      default:
        throw StateError('Invalid event type ${event.type}.');
    }
  }

  /// See [FileSystemMoveEvent.destination].
  ///
  /// For other types of event, always `null`.
  String? get destination => event.type == FileSystemEvent.move
      ? (event as FileSystemMoveEvent).destination
      : null;
}

/// See [FileSystemEvent.type].
///
/// This additionally encodes [FileSystemEvent.isDirectory], which is specified
/// for all event types except deletes.
enum EventType {
  delete,
  createFile,
  createDirectory,
  modifyFile,
  modifyDirectory,
  moveFile,
  moveDirectory;
}
