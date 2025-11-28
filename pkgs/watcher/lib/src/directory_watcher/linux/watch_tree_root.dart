// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../../utils.dart';
import '../../watch_event.dart';
import 'paths.dart';
import 'watch_tree.dart';

/// Linux directory watcher using a [WatchTree].
class WatchTreeRoot {
  final AbsolutePath watchedDirectory;
  final StreamController<WatchEvent> _eventsController;
  final Completer<void> _readyCompleter;

  late final WatchTree watch;

  WatchTreeRoot(
      {required String watchedDirectory,
      required Completer<void> readyCompleter,
      required StreamController<WatchEvent> eventsController})
      : _readyCompleter = readyCompleter,
        _eventsController = eventsController,
        watchedDirectory = AbsolutePath(watchedDirectory) {
    logForTesting?.call('WatchTree(),$watchedDirectory');
    watch = WatchTree(
        watchedDirectory: this.watchedDirectory,
        starting: true,
        emitEvent: _emit,
        onError: _emitError,
        watchedDirectoryWasDeleted: _watchedDirectoryWasDeleted);
    _ready();
  }

  /// Stops watching and closes the event stream.
  void stopWatching() {
    logForTesting?.call('WatchTree,$watchedDirectory,stopWatching');
    _ready();
    watch.stopWatching();
    _eventsController.close();
  }

  /// Handler for when [watchedDirectory] is deleted.
  void _watchedDirectoryWasDeleted() {
    logForTesting
        ?.call('WatchTree,$watchedDirectory,_watchedDirectoryWasDeleted');
    _ready();
    _eventsController.close();
  }

  /// Emits [event] on the event stream.
  void _emit(WatchEvent event) {
    logForTesting?.call('WatchTree,$watchedDirectory,_emit,$event');
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// Emits [e] with stack trace [s] on the event stream.
  void _emitError(Object e, StackTrace s) {
    logForTesting?.call('WatchTree,$watchedDirectory,_emitError,$e');
    _ready();
    if (!_eventsController.isClosed) {
      _eventsController.addError(e, s);
    }
    watch.stopWatching();
  }

  /// Marks the watcher as ready, meaning it has done initial setup and is now
  /// emitting events.
  void _ready() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }
}
