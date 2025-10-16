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

    // A poll does an async directory list then checks mtime on each file. Check
    // handling of a file that is deleted between the two.
    test('deletes during poll', () async {
      await startWatcher();

      for (var i = 0; i != 300; ++i) {
        writeFile('$i');
      }
      // A series of deletes with delays in between for 300ms, which will
      // intersect with the 100ms polling multiple times.
      for (var i = 0; i != 300; ++i) {
        deleteFile('$i');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final events =
          await takeEvents(duration: const Duration(milliseconds: 500));

      // Events should be adds and removes that pair up, with no modify events.
      final adds = <String>{};
      final removes = <String>{};
      for (var event in events) {
        if (event.type == ChangeType.ADD) {
          adds.add(event.path);
        } else if (event.type == ChangeType.REMOVE) {
          removes.add(event.path);
        } else {
          fail('Unexpected event: $event');
        }
      }
      expect(adds, removes);
    });
  });

  // Also test with delayed writes and real mtimes.
  group('with real mtime', () {
    setUp(enableWaitingForDifferentModificationTimes);

    fileTests();
    linkTests(isNative: false);
  });
}
