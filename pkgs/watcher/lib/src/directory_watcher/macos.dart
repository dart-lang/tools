// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../directory_watcher.dart';
import '../resubscribable.dart';
import '../watch_event.dart';
import 'macos/watched_directory_tree.dart';

/// Resubscribable MacOS directory watcher that watches using
/// [_MacosDirectoryWatcher].
class MacosDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  MacosDirectoryWatcher(String directory)
      : super(directory, () => _MacosDirectoryWatcher(directory));
}

/// Macos directory watcher that watches using [WatchedDirectoryTree].
class _MacosDirectoryWatcher
    implements DirectoryWatcher, ManuallyClosedWatcher {
  @override
  final String path;
  @override
  String get directory => path;

  @override
  Stream<WatchEvent> get events => _eventsController.stream;
  final _eventsController = StreamController<WatchEvent>();

  @override
  bool get isReady => _readyCompleter.isCompleted;

  @override
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  late final WatchedDirectoryTree _watchTree;

  _MacosDirectoryWatcher(this.path) {
    _watchTree = WatchedDirectoryTree(
        watchedDirectory: path,
        eventsController: _eventsController,
        readyCompleter: _readyCompleter);
  }

  @override
  void close() => _watchTree.stopWatching();
}
