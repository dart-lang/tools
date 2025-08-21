// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:watcher/src/directory_watcher/windows.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'shared.dart';

void main() {
  watcherFactory = WindowsDirectoryWatcher.new;

  group('Shared Tests:', sharedTests);

  test('DirectoryWatcher creates a WindowsDirectoryWatcher on Windows', () {
    expect(DirectoryWatcher('.'), const TypeMatcher<WindowsDirectoryWatcher>());
  });

  test(
    'Regression test for https://github.com/dart-lang/tools/issues/2110',
    () async {
      late StreamSubscription<WatchEvent> sub;
      try {
        final temp = Directory.systemTemp.createTempSync();
        final watcher = DirectoryWatcher(temp.path);
        final events = <WatchEvent>[];
        sub = watcher.events.listen(events.add);
        await watcher.ready;

        // Create a file in a directory that doesn't exist. This forces the
        // directory to be created first before the child file.
        //
        // When directory creation is detected by the watcher, it calls
        // `Directory.list` on the directory to determine if there's files that
        // have been created or modified. It's possible that the watcher will
        // have already detected the file creation event before `Directory.list`
        // returns. Before https://github.com/dart-lang/tools/issues/2110 was
        // resolved, the check to ensure an event hadn't already been emitted
        // for the file creation was incorrect, leading to the event being
        // emitted again in some circumstances.
        final file = File(p.join(temp.path, 'foo', 'file.txt'))
          ..createSync(recursive: true);

        // Introduce a short delay to allow for the directory watcher to detect
        // the creation of foo/ and foo/file.txt.
        await Future<void>.delayed(const Duration(seconds: 1));

        // There should only be a single file added event.
        expect(events, hasLength(1));
        expect(
          events.first.toString(),
          WatchEvent(ChangeType.ADD, file.path).toString(),
        );
      } finally {
        await sub.cancel();
      }
    },
  );

  // The Windows native watcher has a buffer that overflows if events are not
  // handled quickly enough. The overflow is reliably triggered if enough events
  // arrive during a sync block. The `package:watcher` implementation tries to
  // catch this and recover by starting a new watcher.
  test('Buffer overflow recovery', () async {
    late StreamSubscription<Object> subscription;
    late Directory temp;
    var eventsSeen = 0;
    var errorsSeen = 0;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync();
      final watcher = DirectoryWatcher(temp.path);
      subscription = watcher.events.listen(
        (e) {
          ++eventsSeen;
        },
        onError: (_, __) {
          ++errorsSeen;
        },
      );
      await watcher.ready;
    });

    tearDown(() {
      subscription.cancel();
    });

    // Use a long filename to fill the buffer.
    final file = File('${temp.path}\\file'.padRight(255, 'a'));

    // Repeatedly trigger an overflow, to check that recovery is reliable.
    for (var times = 0; times != 200; ++times) {
      errorsSeen = 0;
      eventsSeen = 0;

      // Syncronously trigger 200 events. Because this is a sync block, the VM
      // won't handle the events, so this has a very high chance of triggering a
      // buffer overflow.
      //
      // If a buffer overflow happens, `package:watcher` turns this into an
      // error on the event stream, so `errorsSeen` will get incremented once.
      // The number of changes 200 is chosen so this is very likely to happen.
      // If there is _not_ an overflow, the 200 events will show on the stream
      // as a single event because they are changes of the same file. So,
      // `eventsSeen` will instead be incremented once.
      for (var i = 0; i != 200; ++i) {
        file.writeAsStringSync('');
      }

      // Events only happen when there is an async gap, wait for such a gap.
      await pumpEventQueue();

      // If everything is going well, there should have been either one event
      // seen or one error seen.
      if (errorsSeen == 0 && eventsSeen == 0) {
        // It looks like the watcher is now broken: there were file changes but
        // no event and no error. Do some non-sync writes to confirm whether
        // the watcher really is now broken.
        for (var i = 0; i != 5; ++i) {
          await file.writeAsString('');
        }
        await pumpEventQueue();
        fail(
          'On attempt ${times + 1}, watcher registered nothing. '
          'On retry, it registered: $errorsSeen error(s), $eventsSeen '
          'event(s).',
        );
      }
    }
  });
}
