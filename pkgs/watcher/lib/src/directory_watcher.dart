// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../watcher.dart';
import 'custom_watcher_factory.dart';
import 'directory_watcher/linux/linux_directory_watcher.dart';
import 'directory_watcher/recursive/recursive_directory_watcher.dart';

/// Watches the contents of a directory and emits [WatchEvent]s when something
/// in the directory has changed.
///
/// On Windows, the underlying SDK `Directory.watch` fails if too many events
/// are received while Dart is busy, for example during a long-running
/// synchronous operation. When this happens, watching is re-established and a
/// "modify" event is emitted for any file still present that lost tracking, in
/// case it changed. By default, the watcher is started in a separate isolate to
/// make this less likely. Pass `runInIsolateOnWindows = false` to not launch an
/// isolate.
///
/// On Linux, the underlying SDK `Directory.watch` fails if the system limit on
/// watchers has been reached. If this happens the SDK exception is thrown, it
/// is a `FileSystemException` with message `Failed to watch path` and
/// OSError `No space left on device`, `errorCode = 28`.
abstract class DirectoryWatcher implements Watcher {
  /// The directory whose contents are being monitored.
  @Deprecated('Expires in 1.0.0. Use DirectoryWatcher.path instead.')
  String get directory;

  /// Creates a new [DirectoryWatcher] monitoring [directory].
  ///
  /// If a native directory watcher is available for this platform, this will
  /// use it. Otherwise, it will fall back to a [PollingDirectoryWatcher].
  ///
  /// If [pollingDelay] is passed, it specifies the amount of time the watcher
  /// will pause between successive polls of the directory contents. Making this
  /// shorter will give more immediate feedback at the expense of doing more IO
  /// and higher CPU usage. Defaults to one second. Ignored for non-polling
  /// watchers.
  ///
  /// On Windows, pass [runInIsolateOnWindows] `false` to not run the watcher
  /// in a separate isolate to reduce buffer exhaustion failures.
  factory DirectoryWatcher(
    String directory, {
    Duration? pollingDelay,
    bool runInIsolateOnWindows = true,
  }) {
    if (FileSystemEntity.isWatchSupported) {
      var customWatcher = createCustomDirectoryWatcher(
        directory,
        pollingDelay: pollingDelay,
      );
      if (customWatcher != null) return customWatcher;
      if (Platform.isLinux) return LinuxDirectoryWatcher(directory);
      if (Platform.isMacOS) {
        return RecursiveDirectoryWatcher(directory, runInIsolate: false);
      }
      if (Platform.isWindows) {
        return RecursiveDirectoryWatcher(
          directory,
          runInIsolate: runInIsolateOnWindows,
        );
      }
    }
    return PollingDirectoryWatcher(directory, pollingDelay: pollingDelay);
  }
}
