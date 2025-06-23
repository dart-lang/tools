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

  test('Regression test for https://github.com/dart-lang/tools/issues/2110',
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
      // have been created or modified. It's possible that the watcher will have
      // already detected the file creation event before `Directory.list`
      // returns. Before https://github.com/dart-lang/tools/issues/2110 was
      // resolved, the check to ensure an event hadn't already been emitted for
      // the file creation was incorrect, leading to the event being emitted
      // again in some circumstances.
      final file = File(p.join(temp.path, 'foo', 'file.txt'))
        ..createSync(recursive: true);

      // Introduce a short delay to allow for the directory watcher to detect
      // the creation of foo/ and foo/file.txt.
      await Future<void>.delayed(const Duration(seconds: 1));

      // There should only be a single file added event.
      expect(events, hasLength(1));
      expect(events.first.toString(),
          WatchEvent(ChangeType.ADD, file.path).toString());
    } finally {
      await sub.cancel();
    }
  });
}
