// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'file_tests.dart';
import 'link_tests.dart';
import 'startup_race_tests.dart';

void main() {
  watcherFactory = (file) =>
      PollingFileWatcher(file, pollingDelay: const Duration(milliseconds: 100));

  // Filesystem modification times can be low resolution, mock them.
  group('with mock mtime', () {
    setUp(enableMockModificationTimes);

    fileTests(isNative: false);
    linkTests(isNative: false);
    startupRaceTests(isNative: false);
  });

// Also test with delayed writes and real mtimes.
  group('with real mtime', () {
    setUp(enableWaitingForDifferentModificationTimes);
    fileTests(isNative: false);
    linkTests(isNative: false);
    // Don't run `startupRaceTests`, polling can't have a race and the test is
    // too slow on Windows when waiting for modification times.
  });
}
