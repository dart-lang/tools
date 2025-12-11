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
      pollingDelay: const Duration(milliseconds: 10));

  /// See [enableSleepUntilNewModificationTime] for a note about the "polling"
  /// tests.
  setUp(enableSleepUntilNewModificationTime);

  fileTests(isNative: false);
  linkTests(isNative: false);

  // A poll does an async directory list that runs "stat" on each file. Check
  // handling of a file that is deleted between the two.
  test('deletes during poll', () async {
    await startWatcher();

    for (var i = 0; i != 300; ++i) {
      writeFile('$i');
    }
    // A series of deletes with delays in between for 300ms, which will
    // intersect with the 10ms polling multiple times.
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
}
