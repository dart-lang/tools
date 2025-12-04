// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../../unix_paths.dart';
import '../../utils.dart';
import '../../watch_event.dart';
import 'directory_tree.dart';
import 'event_tree.dart';
import 'native_watch.dart';

/// MacOS directory watcher using a [DirectoryTree].
///
/// MacOS events from a native watcher can arrive out of order, including in
/// different batches. For example, a modification of `a/1` followed by a
/// move of `a` can be reported as a delete of `a` then in a later batch of
/// events a modification of `a/1`.
///
/// `WatchedDirectoryTree` reports correct events by polling based on event
/// path to determine and report the actual current state. If a directory is
/// mentioned then the whole directory is polled, if a file is mentioned then
/// just the file is polled.
class WatchedDirectoryTree {
  final AbsolutePath watchedDirectory;
  final StreamController<WatchEvent> _eventsController;
  final Completer<void> _readyCompleter;

  late final NativeWatch nativeWatch;
  late final DirectoryTree directoryTree;

  WatchedDirectoryTree(
      {required String watchedDirectory,
      required Completer<void> readyCompleter,
      required StreamController<WatchEvent> eventsController})
      : _readyCompleter = readyCompleter,
        _eventsController = eventsController,
        watchedDirectory = AbsolutePath(watchedDirectory) {
    logForTesting?.call('WatchedDirectoryTree(),$watchedDirectory');
    _watch();
  }

  void _watch() async {
    nativeWatch = NativeWatch(
      watchedDirectory: watchedDirectory,
      watchedDirectoryWasRecreated: _watchedDirectoryWasRecreated,
      watchedDirectoryWasDeleted: _watchedDirectoryWasDeleted,
      onEvents: _onEvents,
      onError: _emitError,
    );
    directoryTree =
        DirectoryTree(watchedDirectory: watchedDirectory, emitEvent: _emit);

    // The native watcher can emit events from before the watch started. Add
    // a delay before marking "ready" to allow those events to arrive and be
    // discarded.
    //
    // See https://github.com/dart-lang/sdk/issues/14373.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _ready();
  }

  /// Stops watching and closes the event stream.
  void stopWatching() {
    logForTesting?.call('WatchedDirectoryTree,$watchedDirectory,stopWatching');
    _ready();
    nativeWatch.close();
    _eventsController.close();
  }

  /// Handler for when [watchedDirectory] is recreated.
  void _watchedDirectoryWasRecreated() {
    logForTesting?.call(
        'WatchedDirectoryTree,$watchedDirectory,_watchedDirectoryWasRecreated');
    // Poll the whole directory and emit events.
    directoryTree.poll(EventTree.singleEvent());
  }

  /// Handler for when [watchedDirectory] is deleted.
  void _watchedDirectoryWasDeleted() {
    logForTesting?.call(
        'WatchedDirectoryTree,$watchedDirectory,_watchedDirectoryWasDeleted');
    _ready();
    nativeWatch.close();
    directoryTree.emitDeleteTree();
    _eventsController.close();
  }

  /// Emits [event] on the event stream.
  ///
  /// If the watcher is not yet ready the event is discarded instead.
  void _emit(WatchEvent event) {
    logForTesting?.call('WatchedDirectoryTree,$watchedDirectory,_emit,$event');
    if (_readyCompleter.isCompleted && !_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// Emits [e] with stack trace [s] on the event stream.
  void _emitError(Object e, StackTrace s) {
    logForTesting?.call('WatchedDirectoryTree,$watchedDirectory,_emitError,$e');
    _ready();
    if (!_eventsController.isClosed) {
      _eventsController.addError(e, s);
      _eventsController.close();
    }
    nativeWatch.close();
  }

  /// Marks the watcher as ready, meaning it has done initial setup and is now
  /// emitting events.
  void _ready() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  void _onEvents(EventTree events) {
    directoryTree.poll(events);
  }
}
