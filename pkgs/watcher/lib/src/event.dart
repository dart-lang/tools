// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Extension type on [FileSystemEvent].
///
/// The [FileSystemDeleteEvent] subclass of [FileSystemEvent] does something
/// surprising for `isDirectory`: it always returns `false`. The constructor
/// accepts a boolean called `isDirectory` but discards it.
///
/// This extension type provides an `isDelete` that returns `null` for delete
/// events, so it's clear that it's unspecified; static creation methods that
/// only take the values that are actually used.
extension type Event(FileSystemEvent event) {
  /// A create event for a file at [path].
  static Event createFile(String path) =>
      Event(FileSystemCreateEvent(path, false));

  /// A create event for a directory at [path].
  static Event createDirectory(String path) =>
      Event(FileSystemCreateEvent(path, true));

  /// A delete event for [path].
  ///
  /// Delete events do not specify whether they are for files or directories.
  static Event delete(String path) => Event(FileSystemDeleteEvent(
      path,
      // `FileSystemDeleteEvent` just discards `isDirectory`.
      false /* isDirectory */));

  /// A modify event for the file at [path].
  static Event modifyFile(String path) => Event(FileSystemModifyEvent(
      path,
      false /* isDirectory */,
      // Don't set it, even pass through from the OS, as it's never used.
      false /* contentChanged */));

  /// A modify event for the directory at [path].
  static Event modifyDirectory(String path) => Event(FileSystemModifyEvent(
      path,
      true /* isDirectory */,
      // `contentChanged` is not used by `package:watcher`, don't set it.
      false));

  /// See [FileSystemEvent.path].
  String get path => event.path;

  bool get isDelete => event.type == FileSystemEvent.delete;
  bool get isCreate => event.type == FileSystemEvent.create;
  bool get isModify => event.type == FileSystemEvent.modify;
  bool get isMove => event.type == FileSystemEvent.move;

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
  String? get destination =>
      isMove ? (event as FileSystemMoveEvent).destination : null;

  /// See [FileSystemEvent.isDirectory].
  ///
  /// For delete events, always `null`.
  bool? get isDirectory => isDelete ? null : event.isDirectory;

  /// All paths mentioned by the event.
  ///
  /// This is [path] plus, for move events, [destination] if it's not `null`.
  Set<String> get paths => {event.path, if (destination != null) destination!};
}

/// See [FileSystemEvent.type].
enum EventType {
  delete,
  createFile,
  createDirectory,
  modifyFile,
  modifyDirectory,
  moveFile,
  moveDirectory;
}
