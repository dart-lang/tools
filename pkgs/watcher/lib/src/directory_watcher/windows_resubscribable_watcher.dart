// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../directory_watcher.dart';
import '../resubscribable.dart';
import 'windows.dart';
import 'windows_isolate_directory_watcher.dart';

class WindowsDirectoryWatcher extends ResubscribableWatcher
    implements DirectoryWatcher {
  @override
  String get directory => path;

  /// Watches [directory].
  ///
  /// If [runInIsolate], runs the watcher in an isolate to reduce the chance of
  /// hitting the Windows-specific buffer exhaustion failure.
  WindowsDirectoryWatcher(String directory, {bool runInIsolate = true})
      : super(
            directory,
            () => runInIsolate
                ? WindowsIsolateDirectoryWatcher(directory)
                : WindowsManuallyClosedDirectoryWatcher(directory));
}
