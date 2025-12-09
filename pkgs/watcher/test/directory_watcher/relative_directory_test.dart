// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:watcher/watcher.dart';

import '../utils.dart';

void main() {
  // Watching a relative path is not a great idea because the meaning of the
  // path changes if `Directory.current` changes, leading to surprising and
  // undefined behavior. But released `package:watcher` allows it so at least
  // check basic functionality works.
  //
  // `Directory.current` is shared across the VM so only one test can change it
  // at a time. Solve that by having this be the only test that changes it and
  // testing both the native and polling watcher in the same test.
  test('watch relative directory', () async {
    final testDirectory = Directory(d.sandbox);
    final oldDirectory = Directory.current;
    try {
      Directory.current = testDirectory;

      for (final watcherFactory in [
        DirectoryWatcher.new,
        (String path) => PollingDirectoryWatcher(path,
            pollingDelay: const Duration(milliseconds: 1))
      ]) {
        writeFile('dir/a.txt');
        writeFile('dir/b.txt');
        writeFile('dir/c.txt');

        final watcher = watcherFactory('dir');
        final events = <WatchEvent>[];
        final subscription = watcher.events.listen(events.add);
        await watcher.ready;

        writeFile('dir/a.txt', contents: 'modified');
        renameFile('dir/b.txt', 'dir/e.txt');
        deleteFile('dir/c.txt');
        writeFile('dir/d.txt');

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        expect(
            events.map((e) => e.toString()).toSet(),
            {
              'modify ${p.join('dir', 'a.txt')}',
              'remove ${p.join('dir', 'b.txt')}',
              'add ${p.join('dir', 'e.txt')}',
              'remove ${p.join('dir', 'c.txt')}',
              'add ${p.join('dir', 'd.txt')}',
            },
            reason: 'With watcher $watcher.');

        deleteDir('dir');
      }
    } finally {
      Directory.current = oldDirectory;
    }
  });
}
