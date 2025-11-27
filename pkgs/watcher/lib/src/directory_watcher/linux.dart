// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../directory_watcher.dart';
import '../resubscribable.dart';
import '../watch_event.dart';
import 'linux/watch_tree_root.dart';

/// Resubscribable Linux directory watcher that watches using
/// [_LinuxDirectoryWatcher].
class LinuxDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  LinuxDirectoryWatcher(String directory)
      : super(directory, () => _LinuxDirectoryWatcher(directory));
}

/// Linux directory watcher that watches using [WatchTreeRoot].
class _LinuxDirectoryWatcher
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

  late final WatchTreeRoot _watchTree;

  _LinuxDirectoryWatcher(this.path) {
    _watchTree = WatchTreeRoot(
        watchedDirectory: path,
        eventsController: _eventsController,
        readyCompleter: _readyCompleter);
  }

  @override
  void close() => _watchTree.stopWatching();
}
