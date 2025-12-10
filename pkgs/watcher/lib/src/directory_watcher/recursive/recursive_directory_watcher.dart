// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../../directory_watcher.dart';
import '../../resubscribable.dart';
import '../../watch_event.dart';
import 'isolate_recursive_directory_watcher.dart';
import 'watched_directory_tree.dart';

/// Directory watcher that watches using [WatchedDirectoryTree].
///
/// Optionally, runs the watcher in a new isolate.
class RecursiveDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  /// Watches [directory].
  ///
  /// If [runInIsolate], runs the watcher in an isolate to reduce the chance of
  /// hitting the Windows-specific buffer exhaustion failure.
  RecursiveDirectoryWatcher(String directory, {required bool runInIsolate})
      : super(
            directory,
            () => runInIsolate
                ? IsolateRecursiveDirectoryWatcher(directory)
                : ManuallyClosedRecursiveDirectoryWatcher(directory));
}

/// Manually closed directory watcher that watches using [WatchedDirectoryTree].
class ManuallyClosedRecursiveDirectoryWatcher
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

  ManuallyClosedRecursiveDirectoryWatcher(this.path) {
    _watchTree = WatchedDirectoryTree(
        watchedDirectory: path,
        eventsController: _eventsController,
        readyCompleter: _readyCompleter);
  }

  @override
  void close() => _watchTree.stopWatching();
}
