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

  // Regression test for https://github.com/dart-lang/tools/issues/2152:
  // watcher can throws if a directory is created then quickly deleted.
  group('Transient directory', () {
    late StreamSubscription<Object> subscription;
    late Directory temp;
    late Watcher watcher;
    late int errorsSeen;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync();
      watcher = DirectoryWatcher(temp.path);
      errorsSeen = 0;
      subscription = watcher.events.listen(
        (e) {},
        onError: (Object e, _) {
          print('Event stream error: $e');
          ++errorsSeen;
        },
      );
      await watcher.ready;
    });

    tearDown(() {
      subscription.cancel();
    });

    test('does not break watching', () async {
      // Iterate creating 10 directories and deleting 1-10 of them. This means
      // the directories will exist for different lengths of times, exploring
      // possible race conditions in directory handling.
      for (var i = 0; i != 50; ++i) {
        for (var j = 0; j != 10; ++j) {
          File('${temp.path}\\$j\\file').createSync(recursive: true);
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
        for (var j = 0; j != i % 10 + 1; ++j) {
          final d = Directory('${temp.path}\\$j');
          d.deleteSync(recursive: true);
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      expect(errorsSeen, 0);
    });
  });

  // The Windows native watcher has a buffer that gets exhausted if events are
  // not handled quickly enough. Then, it throws an error and stops watching.
  // The exhaustion is reliably triggered if enough events arrive during a sync
  // block. The `package:watcher` implementation tries to catch this and recover
  // by starting a new watcher.
  group('Buffer exhaustion', () {
    late StreamSubscription<Object> subscription;
    late Directory temp;
    late int eventsSeen;
    late int errorsSeen;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync();
      final watcher = DirectoryWatcher(temp.path);

      eventsSeen = 0;
      errorsSeen = 0;
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

    test('recovery', () async {
      // Use a long filename to fill the buffer.
      final file = File('${temp.path}\\file'.padRight(255, 'a'));

      // Repeatedly trigger buffer exhaustion, to check that recovery is
      // reliable.
      for (var times = 0; times != 200; ++times) {
        errorsSeen = 0;
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
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // If everything is going well, there should have been either one event
        // seen or one error seen.
        if (errorsSeen == 0 && eventsSeen == 0) {
          // It looks like the watcher is now broken: there were file changes
          // but no event and no error. Do some non-sync writes to confirm
          // whether the watcher really is now broken.
          for (var i = 0; i != 5; ++i) {
            await file.writeAsString('');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          fail(
            'On attempt ${times + 1}, watcher registered nothing. '
            'On retry, it registered: $errorsSeen error(s), $eventsSeen '
            'event(s).',
          );
        }
      }
    });
  });
}
