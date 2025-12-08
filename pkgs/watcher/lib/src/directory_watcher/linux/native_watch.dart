// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../../event.dart';
import '../../event_batching.dart';
import '../../paths.dart';
import '../../testing.dart';

/// Watches a directory with the native Linux watcher.
///
/// As described in https://github.com/dart-lang/sdk/issues/61860 and
/// https://github.com/dart-lang/sdk/issues/61861 the native watcher has problems
/// with directory moves.
///
/// Because watching is based on inodes, the native watch follows the directory
/// move. The VM notices that the directory is "deleted" and closes the watch.
///
/// There are three different problems that can happen with a new
/// `Directory.watch` on the "new" path that is the move destination of the.
/// moved directory.
///
/// The VM might notice that the inode is already watched and re-use the
/// underlying watch. This leads to the new watch reporting events under the old
/// path, not under the new path as expected.
///
/// And, the VM might interpret the "delete" of the old path as being a delete
/// of the new path, and close the stream.
///
/// Finally, the VM might actually create a new watch, leading to events being
/// reported against the new path, but buffering of events can mean that the
/// first events reported are actually from the old path but renamed to the new
/// path. This can lead to a "delete" event arriving for the new path when the
/// directory has not been deleted at all, in fact it has just been created.
///
/// This class detects such problems and reports them. There is no way to
/// recover here, so the `WatchTree` will list the directory to get the updated
/// state and try watching again.
class NativeWatch {
  final AbsolutePath watchedDirectory;

  /// Called when an issue due to a directory move is detected.
  ///
  /// This watch should be discarded and a new one created. The directory will
  /// need to be listed to check the state.
  final void Function() _restartWatching;

  /// Called when [watchedDirectory] is deleted.
  final void Function() _watchedDirectoryWasDeleted;

  /// Called with batches of events.
  ///
  /// Move events have been split into separate create and delete events.
  final void Function(List<Event> events) _onEvents;

  /// Called with native watch errors.
  final void Function(Object, StackTrace) _onError;

  StreamSubscription<List<Event>>? _subscription;

  /// Closes the watch.
  void close() {
    logForTesting?.call('NativeWatch,$watchedDirectory,close');
    _subscription?.cancel();
    _subscription = null;
  }

  /// Watches [watchedDirectory].
  ///
  /// Pass [restartWatching], [watchedDirectoryWasDeleted], [onEvents] and
  /// [onError] handlers.
  ///
  /// If watching fails as described in the class comment, [restartWatching] is
  /// called. The directory should be listed to check the state and a new
  /// `NativeWatch` created.
  NativeWatch({
    required this.watchedDirectory,
    required void Function() restartWatching,
    required void Function() watchedDirectoryWasDeleted,
    required void Function(List<Event>) onEvents,
    required void Function(Object, StackTrace) onError,
  })  : _onError = onError,
        _onEvents = onEvents,
        _watchedDirectoryWasDeleted = watchedDirectoryWasDeleted,
        _restartWatching = restartWatching {
    logForTesting?.call('NativeWatch(),$watchedDirectory');
    _subscription = watchedDirectory
        .watch()
        .batchNearbyMicrotasksAndConvertEvents()
        .listen(_onData, onError: _onError);
  }

  void _onData(List<Event> events) {
    logForTesting?.call('NativeWatch,$watchedDirectory,onData,$events');
    // Check for events that indicate a watch failure. Convert move events into
    // separate create and delete events.
    final processedEvents = <Event>[];
    for (var event in events) {
      if (event.type == EventType.delete &&
          event.absolutePath == watchedDirectory) {
        // A delete event for [watchDirectory] usually indicates that the
        // watched directory was deleted. But, it might be an incorrect event
        // that is the deletion event for the old location in a move. So, check
        // if the directory is actually now missing.
        if (watchedDirectory.typeSync() == FileSystemEntityType.directory) {
          // The directory is still present, indicating either a watch failure
          // or that the directoy has been replaced with a new one. Either way,
          // restart watching.
          _restartWatching();
        } else {
          // The directory is gone, the delete event looks correct: report it.
          _watchedDirectoryWasDeleted();
        }
        // Don't emit any events from the bundle: both watch restart and
        // deletion mean the events aren't needed.
        return;
      }

      // If the event is for the wrong directory, watching has failed, restart.
      // Don't emit any events from the bundle, restarting watching will take
      // care of checking the current state.
      if (!event.isIn(watchedDirectory)) {
        _restartWatching();
        return;
      }

      // Split moves into separate create and delete events.
      switch (event.type) {
        case EventType.moveDirectory:
          processedEvents.add(Event.createDirectory(event.destination!));
          processedEvents.add(Event.delete(event.path));

        case EventType.moveFile:
          processedEvents.add(Event.createFile(event.destination!));
          processedEvents.add(Event.delete(event.path));

        default:
          processedEvents.add(event);
      }
    }

    // No watch failure was encountered, emit the events.
    _onEvents(processedEvents);
  }
}
