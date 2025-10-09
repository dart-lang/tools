// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'file_tests.dart';
import 'link_tests.dart';

void main() {
  // Use a short delay to make the tests run quickly.
  watcherFactory = (dir) => PollingDirectoryWatcher(dir,
      pollingDelay: const Duration(milliseconds: 100));

  // Filesystem modification times can be low resolution, mock them.
  group('with mock mtime', () {
    setUp(enableMockModificationTimes);

    fileTests();
    linkTests(isNative: false);

    test('does not notify if the modification time did not change', () async {
      writeFile('a.txt', contents: 'before');
      writeFile('b.txt', contents: 'before');
      await startWatcher();
      writeFile('a.txt', contents: 'after', updateModified: false);
      writeFile('b.txt', contents: 'after');
      await expectModifyEvent('b.txt');
    });
  });

  // Also test with delayed writes and real mtimes.
  group('with real mtime', () {
    setUp(enableWaitingForDifferentModificationTimes);

    fileTests();
    linkTests(isNative: false);
  });
}
