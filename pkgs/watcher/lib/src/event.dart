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
extension type Event._(FileSystemEvent _event) {
  /// Converts [event] to an [Event].
  ///
  /// Returns `null` and asserts `false` if [event] is unexpected on this
  /// platform. So, it will cause tests to fail but real code can continue
  /// ignoring the event.
  ///
  /// Returns `null` if [event] should be ignored on this platform.
  static Event? checkAndConvert(FileSystemEvent event) {
    var result = Event._(event);
    if (Platform.isMacOS) {
      if (result.type.isNeverReceivedOnMacOS) {
        assert(false);
        return null;
      }
    } else if (Platform.isWindows) {
      if (result.type.isIgnoredOnWindows) {
        return null;
      }
    } else if (Platform.isLinux) {
      if (result.type.isIgnoredOnLinux) {
        return null;
      }
    }
    return result;
  }

  /// Returns an iterable containing this event, split to a "create" and a
  /// "delete" event if it's a move event.
  Iterable<Event> splitIfMove() sync* {
    if (type != EventType.moveFile && type != EventType.moveDirectory) {
      yield this;
      return;
    }
    final destination = this.destination;
    yield Event._(FileSystemDeleteEvent(path, type == EventType.moveDirectory));
    if (destination != null) {
      yield Event._(
          FileSystemCreateEvent(destination, type == EventType.moveDirectory));
    }
  }

  /// A create event for a file at [path].
  static Event createFile(String path) =>
      Event._(FileSystemCreateEvent(path, false));

  /// A create event for a directory at [path].
  static Event createDirectory(String path) =>
      Event._(FileSystemCreateEvent(path, true));

  /// A delete event for [path].
  ///
  /// Delete events do not specify whether they are for files or directories.
  static Event delete(String path) => Event._(FileSystemDeleteEvent(
      path,
      // `FileSystemDeleteEvent` just discards `isDirectory`.
      false /* isDirectory */));

  /// A modify event for the file at [path].
  static Event modifyFile(String path) => Event._(FileSystemModifyEvent(
      path,
      false /* isDirectory */,
      // Don't set `contentChanged`, even pass through from the OS, as
      // `package:watcher` never reads it.
      false /* contentChanged */));

  /// See [FileSystemEvent.path].
  String get path => _event.path;

  EventType get type {
    switch (_event.type) {
      case FileSystemEvent.create:
        return _event.isDirectory
            ? EventType.createDirectory
            : EventType.createFile;
      case FileSystemEvent.delete:
        return EventType.delete;
      case FileSystemEvent.modify:
        return _event.isDirectory
            ? EventType.modifyDirectory
            : EventType.modifyFile;
      case FileSystemEvent.move:
        return _event.isDirectory
            ? EventType.moveDirectory
            : EventType.moveFile;
      default:
        throw StateError('Invalid event type ${_event.type}.');
    }
  }

  /// See [FileSystemMoveEvent.destination].
  ///
  /// For other types of event, always `null`.
  String? get destination => _event.type == FileSystemEvent.move
      ? (_event as FileSystemMoveEvent).destination
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

  bool get isNeverReceivedOnMacOS {
    // See https://github.com/dart-lang/sdk/issues/14806.
    if (this == moveFile || this == moveDirectory) {
      return true;
    }
    if (this == modifyDirectory) return true;
    return false;
  }

  bool get isIgnoredOnWindows {
    // Ignore [modifyDirectory] because it's always accompanied by either
    // [createDirectory] or [deleteDirectory].
    return this == modifyDirectory;
  }

  bool get isIgnoredOnLinux {
    // Ignore [modifyDirectory], it arrives when the directory attributes
    // changed which is not useful.
    return this == modifyDirectory;
  }
}
