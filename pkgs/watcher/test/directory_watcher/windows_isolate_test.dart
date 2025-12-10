// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')
@Timeout.factor(2)
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

void main() {
  // The Windows native watcher has a buffer that gets exhausted if events are
  // not handled quickly enough. Then, it throws an error and stops watching.
  // The exhaustion is reliably triggered if enough events arrive during a sync
  // block. The `package:watcher` implementation tries to catch this and recover
  // by starting a new watcher.
  for (final runInIsolate in [false, true]) {
    late StreamSubscription<Object> subscription;
    late Directory temp;
    late int eventsSeen;
    late int recoveriesSeen;
    late int totalRecoveriesSeen;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync();
      final watcher =
          DirectoryWatcher(temp.path, runInIsolateOnWindows: runInIsolate);
      // To recover from an error "modify" is sent for files that still exist,
      // so any event on this file indicates a recovery.
      File('${temp.path}\\recovery.txt').writeAsStringSync('');

      eventsSeen = 0;
      recoveriesSeen = 0;
      totalRecoveriesSeen = 0;
      subscription = watcher.events.listen(
        (e) {
          if (e.path.contains('recovery.txt')) {
            ++recoveriesSeen;
          } else {
            ++eventsSeen;
          }
        },
      );
      await watcher.ready;
    });

    tearDown(() {
      subscription.cancel();
    });

    test(
        runInIsolate
            ? 'No buffer exhaustion if running in isolate'
            : 'Recover from buffer exhaustion if not running in isolate',
        () async {
      // Use a long filename to fill the buffer.
      final file = File('${temp.path}\\file'.padRight(255, 'a'));

      // Repeatedly trigger buffer exhaustion, to check that recovery is
      // reliable.
      for (var times = 0; times != 200; ++times) {
        recoveriesSeen = 0;
        eventsSeen = 0;

        // Syncronously trigger 200 events. Because this is a sync block, the VM
        // won't handle the events, so this has a very high chance of triggering
        // a buffer exhaustion.
        //
        // If a buffer exhaustion happens, `package:watcher` turns this into an
        // error on the event stream, so `errorsSeen` will get incremented once.
        // The number of changes 200 is chosen so this is very likely to happen.
        // If there is _not_ an exhaustion, the 200 events will show on the
        // stream as a single event because they are changes of the same file.
        // So, `eventsSeen` will instead be incremented once.
        for (var i = 0; i != 200; ++i) {
          file.writeAsStringSync('');
        }

        // Events only happen when there is an async gap, wait for such a gap.
        // The event usually arrives in under 10ms, try for 100ms.
        var tries = 0;
        while (recoveriesSeen == 0 && eventsSeen == 0 && tries < 10) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          ++tries;
        }

        totalRecoveriesSeen += recoveriesSeen;

        // If everything is going well, there should have been either one event
        // seen or one error seen.
        if (recoveriesSeen == 0 && eventsSeen == 0) {
          // It looks like the watcher is now broken: there were file changes
          // but no event and no error. Do some non-sync writes to confirm
          // whether the watcher really is now broken.
          for (var i = 0; i != 5; ++i) {
            await file.writeAsString('');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          fail(
            'On attempt ${times + 1}, watcher registered nothing. '
            'On retry, it registered: $recoveriesSeen recoveries, $eventsSeen '
            'event(s).',
          );
        }
      }

      // Buffer exhaustion is likely without the isolate but not guaranteed.
      if (runInIsolate) {
        expect(totalRecoveriesSeen, 0);
      } else {
        expect(totalRecoveriesSeen, greaterThan(150));
      }
    });
  }
}
