// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../../event.dart';
import '../../unix_paths.dart';
import '../../utils.dart';
import 'event_tree.dart';

/// Watches a directory tree with the native MacOS watcher.
///
/// Handles incorrect closure of the watch due to a delete event from before
/// the watch started, by re-opening the watch if the directory still exists.
/// See https://github.com/dart-lang/sdk/issues/14373.
class NativeWatch {
  final AbsolutePath watchedDirectory;

  /// Called when [watchedDirectory] is recreated.
  final void Function() _watchedDirectoryWasRecreated;

  /// Called when [watchedDirectory] is deleted.
  final void Function() _watchedDirectoryWasDeleted;

  /// Called with trees of events.
  final void Function(EventTree events) _onEvents;

  /// Called with native watch errors.
  final void Function(Object, StackTrace) _onError;

  StreamSubscription<List<Event>>? _subscription;

  /// Watches [watchedDirectory].
  ///
  /// Pass [watchedDirectoryWasDeleted], [onEvents] and [onError] handlers.
  NativeWatch({
    required this.watchedDirectory,
    required void Function() watchedDirectoryWasRecreated,
    required void Function() watchedDirectoryWasDeleted,
    required void Function(EventTree) onEvents,
    required void Function(Object, StackTrace) onError,
  })  : _onError = onError,
        _onEvents = onEvents,
        _watchedDirectoryWasRecreated = watchedDirectoryWasRecreated,
        _watchedDirectoryWasDeleted = watchedDirectoryWasDeleted {
    logForTesting?.call('NativeWatch(),$watchedDirectory');
    _watch();
  }

  void _watch() {
    _subscription?.cancel();
    _subscription = watchedDirectory
        .watch(recursive: true)
        .batchAndConvertEvents()
        .listen(_onData, onError: _onError, onDone: _onDone);
  }

  /// Closes the watch.
  void close() {
    logForTesting?.call('NativeWatch,$watchedDirectory,close');
    _subscription?.cancel();
    _subscription = null;
  }

  void _onData(List<Event> events) {
    logForTesting?.call('NativeWatch,$watchedDirectory,onData,$events');
    final eventTree = EventTree();
    for (final event in events) {
      // Delete of the watched directory is handled when the stream closes.
      if (event.type == EventType.delete &&
          event.absolutePath == watchedDirectory) {
        continue;
      }
      eventTree.add(event.absolutePath.relativeTo(watchedDirectory));
    }
    _onEvents(eventTree);
  }

  void _onDone() {
    logForTesting?.call('NativeWatch,$watchedDirectory,onDone');
    // Check whether the directory exists and report if it was deleted or
    // recreated. If it was recreated, restart the watch.
    if (watchedDirectory.typeSync() == FileSystemEntityType.directory) {
      _watchedDirectoryWasRecreated();
      _watch();
    } else {
      _watchedDirectoryWasDeleted();
    }
  }
}
