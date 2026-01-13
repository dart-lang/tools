// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../../event.dart';
import '../../event_batching.dart';
import '../../paths.dart';
import '../../testing.dart';
import 'event_tree.dart';

/// Watches a directory with `Directory.watch(recursive: true)` on MacOS or
/// Windows.
///
/// Handles incorrect closure of the watch due to a delete event from before
/// the watch started, by re-opening the watch if the directory still exists.
/// See https://github.com/dart-lang/sdk/issues/14373.
///
/// Handles deletion of the watched directory on Windows by watching the parent
/// directory.
class RecursiveNativeWatch {
  final AbsolutePath watchedDirectory;

  /// Called when [watchedDirectory] is recreated.
  final void Function() _watchedDirectoryWasRecreated;

  /// Called when [watchedDirectory] is deleted.
  final void Function() _watchedDirectoryWasDeleted;

  /// Called with trees of events.
  final void Function(EventTree events) _onEvents;

  /// Called with native watch errors.
  final void Function(Object, StackTrace) _onError;

  /// The underlying batched event stream.
  StreamSubscription<List<Event>>? _subscription;

  /// On Windows only, the parent directory event stream.
  StreamSubscription<FileSystemEvent>? _parentSubscription;

  /// Watches [watchedDirectory].
  ///
  /// Pass [watchedDirectoryWasDeleted], [onEvents] and [onError] handlers.
  RecursiveNativeWatch({
    required this.watchedDirectory,
    required void Function() watchedDirectoryWasRecreated,
    required void Function() watchedDirectoryWasDeleted,
    required void Function(EventTree) onEvents,
    required void Function(Object, StackTrace) onError,
  }) : _onError = onError,
       _onEvents = onEvents,
       _watchedDirectoryWasRecreated = watchedDirectoryWasRecreated,
       _watchedDirectoryWasDeleted = watchedDirectoryWasDeleted {
    logForTesting?.call('NativeWatch(),$watchedDirectory');
    _watch();
    if (Platform.isWindows) _watchParent();
  }

  void _watch() {
    _subscription?.cancel();
    // In older SDKs watcher exceptions on Windows are not sent over the stream
    // and must be caught with a zone handler.
    runZonedGuarded(() {
      _subscription = watchedDirectory
          .watch(recursive: true)
          .batchAndConvertEventsForPlatform()
          .listen(
            _onData,
            onError: _restartWatchOnOverflowOr(_onError),
            onDone: _onDone,
          );
    }, _restartWatchOnOverflowOr(Error.throwWithStackTrace));
  }

  /// Handles deletes and moves of [watchedDirectory] on Windows.
  ///
  /// Deletes can be signalled by an exception, but moves are not signalled
  /// at all. So, handle both by watching the parent directory.
  ///
  /// See https://github.com/dart-lang/sdk/issues/62193 and
  /// https://github.com/dart-lang/sdk/issues/62194.
  void _watchParent() {
    final parent = watchedDirectory.parent;
    if (parent == watchedDirectory) {
      // Watching a filesystem root: it can't be deleted.
      return;
    }
    final parentStream = parent.watch(recursive: false);
    _parentSubscription = parentStream.listen(
      (event) {
        // Only look at events for [watchedDirectory].
        final eventPath = AbsolutePath(event.path);
        if (eventPath.basename != watchedDirectory.basename) {
          return;
        }
        // The directory was deleted if there is an event saying it was deleted,
        // or if there was any event and it no longer exists. Note that it might
        // still exist but be a different+new directory: this needs handling as
        // a delete because the new directory would need a new native watch.
        if (event is FileSystemMoveEvent ||
            event is FileSystemDeleteEvent ||
            (eventPath.typeSync() == FileSystemEntityType.notFound)) {
          _watchedDirectoryWasDeleted();
        }
      },
      onError: (error) {
        // Ignore errors, simply close the stream. The user listens on
        // [directory], and while it can fail to listen on the parent, we may
        // still be able to listen on the path requested.
        _parentSubscription?.cancel();
        _parentSubscription = null;
      },
    );
  }

  /// Closes the watch.
  void close() {
    logForTesting?.call('NativeWatch,$watchedDirectory,close');
    _subscription?.cancel();
    _subscription = null;
    _parentSubscription?.cancel();
    _parentSubscription = null;
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
      // Drop paths outside the watched directory, which could only be due to
      // a move event destination path. Currently the VM reports moves to
      // outside the watched directory as deletes, so there aren't any such move
      // events, but it's as easy and more future proof to handle correctly by
      // dropping instead of throwing.
      final path = event.absolutePath.tryRelativeTo(watchedDirectory);
      if (path != null) {
        eventTree.add(path);
      }
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

  /// Intercepts and handles Windows-specific exceptions.
  ///
  /// A "closed unexpectedly" error happens on Windows when the event
  /// stream is not serviced quickly enough and the OS buffer fills.
  ///
  /// And, a `SocketException` happens on Windows when the watched directory
  /// is deleted.
  void Function(Object, StackTrace) _restartWatchOnOverflowOr(
    void Function(Object, StackTrace) otherwise,
  ) {
    return (error, stackTrace) async {
      if (error is FileSystemException &&
          error.message.startsWith('Directory watcher closed unexpectedly')) {
        // Wait to work around https://github.com/dart-lang/sdk/issues/61378.
        // Give the VM time to reset state after the error. See the issue for
        // more discussion of the workaround.
        // TODO(davidmorgan): remove the wait once min SDK version is 3.10.
        // The recovery test in `windows_isolate_test.dart` will continue to
        // pass if it's no longer needed.
        await _subscription?.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        _watch();
        _watchedDirectoryWasRecreated();
      } else if ((error is SocketException &&
              error.message.contains('SocketException: Access is denied')) ||
          (error is FileSystemException &&
              error.message.contains('SocketException: Access is denied'))) {
        // This can happen if the watched directory is deleted, see
        // [_watchParent] which handles both deletes and moves. Ignore the
        // exception.
      } else {
        otherwise(error, stackTrace);
      }
    };
  }
}

extension _BatchEvents on Stream<FileSystemEvent> {
  /// Batches events based on the current platform.
  ///
  /// On Windows, events need to be batched by path for two reasons: to handle
  /// duplicate events together and because polling the filesystem state too
  /// quickly after an event arrives can give incorrect results. In particular,
  /// if the entity is a newly-created link to a directory then polling too soon
  /// reports that it is a directory, not a link. By testing, a 1ms delay looks
  /// sufficient: incorrect type dropped from 150/1000 to 0/10000. Use a 5ms
  /// delay to have a margin for error for load and machine performance.
  ///
  /// On other platforms, which means MacOS, events are batched by "nearby
  /// microtask" to pick up all the events that the VM sends "together".
  Stream<List<Event>> batchAndConvertEventsForPlatform() {
    return Platform.isWindows
        ? batchBufferedByPathAndConvertEvents(
            duration: const Duration(milliseconds: 5),
          )
        : batchNearbyMicrotasksAndConvertEvents();
  }
}
