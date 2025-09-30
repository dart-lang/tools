// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

import '../utils.dart';

/// Tests for a startup race that affects MacOS.
///
/// As documented in `File.watch`, changes from shortly _before_ the `watch`
/// method is called might be reported on MacOS. They should be ignored.
void startupRaceTests({required bool isNative}) {
  test('ignores events from before watch starts', () async {
    // Write then immediately watch 100 times and count the events received.
    var events = 0;
    final futures = <Future<void>>[];
    for (var i = 0; i != 100; ++i) {
      writeFile('file$i.txt');
      await startWatcher(path: 'file$i.txt');
      futures.add(
        waitForEvent().then((event) {
          if (event != null) ++events;
        }),
      );
    }
    await Future.wait(futures);

    // TODO(davidmorgan): the MacOS watcher currently does get unwanted events,
    // fix it.
    if (isNative && Platform.isMacOS) {
      expect(events, greaterThan(10));
    } else {
      expect(events, 0);
    }
  });
}
