// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:watcher/src/utils.dart';

import '../utils.dart';

void fileTests({required bool isNative}) {
  for (var i = 0; i != runsPerTest; ++i) {
    _fileTests(isNative: isNative);
  }
}

void _fileTests({required bool isNative}) {
  test('does not notify for files that already exist when started', () async {
    // Make some pre-existing files.
    writeFile('a.txt');
    writeFile('b.txt');

    await startWatcher();

    // Change one after the watcher is running.
    writeFile('b.txt', contents: 'modified');

    // We should get a modify event for the changed file, but no add events
    // for them before this.
    await expectModifyEvent('b.txt');
  });

  test('notifies when a file is added', () async {
    await startWatcher();
    writeFile('file.txt');
    await expectAddEvent('file.txt');
  });

  test('notifies when a file is modified', () async {
    writeFile('file.txt');
    await startWatcher();
    writeFile('file.txt', contents: 'modified');
    await expectModifyEvent('file.txt');
  });

  test('notifies when a file is removed', () async {
    writeFile('file.txt');
    await startWatcher();
    deleteFile('file.txt');
    await expectRemoveEvent('file.txt');
  });

  test('notifies when a file is modified multiple times', () async {
    writeFile('file.txt');
    await startWatcher();
    writeFile('file.txt', contents: 'modified');
    await expectModifyEvent('file.txt');
    writeFile('file.txt', contents: 'modified again');
    await expectModifyEvent('file.txt');
  });

  test('notifies even if the file contents are unchanged', () async {
    writeFile('a.txt', contents: 'same');
    writeFile('b.txt', contents: 'before');
    await startWatcher();

    if (!isNative) sleepUntilNewModificationTime();
    writeFile('a.txt', contents: 'same');
    writeFile('b.txt', contents: 'after');
    await inAnyOrder([isModifyEvent('a.txt'), isModifyEvent('b.txt')]);
  });

  test('when the watched directory is deleted, removes all files', () async {
    writeFile('dir/a.txt');
    writeFile('dir/b.txt');

    await startWatcher(path: 'dir');

    deleteDir('dir');
    await inAnyOrder([isRemoveEvent('dir/a.txt'), isRemoveEvent('dir/b.txt')]);
  });

  test('when the watched directory is moved, removes all files', () async {
    writeFile('dir/a.txt');
    writeFile('dir/b.txt');

    await startWatcher(path: 'dir');

    renameDir('dir', 'moved_dir');
    createDir('dir');
    await inAnyOrder([isRemoveEvent('dir/a.txt'), isRemoveEvent('dir/b.txt')]);
  });

  // Regression test for b/30768513.
  test(
      "doesn't crash when the directory is moved immediately after a subdir "
      'is added', () async {
    writeFile('dir/a.txt');
    writeFile('dir/b.txt');

    await startWatcher(path: 'dir');

    createDir('dir/subdir');
    renameDir('dir', 'moved_dir');
    createDir('dir');
    await inAnyOrder([isRemoveEvent('dir/a.txt'), isRemoveEvent('dir/b.txt')]);
  });

  group('moves', () {
    test('notifies when a file is moved within the watched directory',
        () async {
      writeFile('old.txt');
      await startWatcher();
      renameFile('old.txt', 'new.txt');

      await inAnyOrder([isAddEvent('new.txt'), isRemoveEvent('old.txt')]);
    });

    test('notifies when a file is moved from outside the watched directory',
        () async {
      writeFile('old.txt');
      createDir('dir');
      await startWatcher(path: 'dir');

      renameFile('old.txt', 'dir/new.txt');
      await expectAddEvent('dir/new.txt');
    });

    test('notifies when a file is moved outside the watched directory',
        () async {
      writeFile('dir/old.txt');
      await startWatcher(path: 'dir');

      renameFile('dir/old.txt', 'new.txt');
      await expectRemoveEvent('dir/old.txt');
    });

    test('notifies when a file is moved onto an existing one', () async {
      writeFile('from.txt');
      writeFile('to.txt', contents: 'different');
      await startWatcher();

      renameFile('from.txt', 'to.txt');
      await inAnyOrder([isRemoveEvent('from.txt'), isModifyEvent('to.txt')]);
    });
  });

  group('clustered changes', () {
    test("doesn't notify when a file is created and then immediately removed",
        () async {
      writeFile('test.txt');
      await startWatcher();
      writeFile('file.txt');
      deleteFile('file.txt');
    });

    test(
        'reports a modification when a file is deleted and then immediately '
        'recreated', () async {
      writeFile('file.txt');
      await startWatcher();

      deleteFile('file.txt');
      writeFile('file.txt', contents: 're-created');

      await expectModifyEvent('file.txt');
    });

    test(
        'reports a modification when a file is moved and then immediately '
        'recreated', () async {
      writeFile('old.txt');
      await startWatcher();

      renameFile('old.txt', 'new.txt');
      writeFile('old.txt', contents: 're-created');

      await inAnyOrder([isModifyEvent('old.txt'), isAddEvent('new.txt')]);
    });

    test(
        'reports a removal when a file is modified and then immediately '
        'removed', () async {
      writeFile('file.txt');
      await startWatcher();

      writeFile('file.txt', contents: 'modified');
      deleteFile('file.txt');

      await expectRemoveEvent('file.txt');
    });

    test('reports an add when a file is added and then immediately modified',
        () async {
      await startWatcher();

      writeFile('file.txt');
      writeFile('file.txt', contents: 'modified');

      await expectAddEvent('file.txt');
    });
  });

  group('subdirectories', () {
    test('watches files in subdirectories', () async {
      await startWatcher();
      writeFile('a/b/c/d/file.txt');
      await expectAddEvent('a/b/c/d/file.txt');
    });

    test(
        'notifies when a subdirectory is moved within the watched directory '
        'and then its contents are modified', () async {
      writeFile('old/file.txt');
      await startWatcher();

      renameDir('old', 'new');
      await inAnyOrder(
          [isRemoveEvent('old/file.txt'), isAddEvent('new/file.txt')]);

      writeFile('new/file.txt', contents: 'modified');
      await expectModifyEvent('new/file.txt');
    });

    test('notifies when a file is replaced by a subdirectory', () async {
      writeFile('new');
      writeFile('old/file.txt');
      await startWatcher();

      deleteFile('new');
      renameDir('old', 'new');
      await inAnyOrder([
        isRemoveEvent('new'),
        isRemoveEvent('old/file.txt'),
        isAddEvent('new/file.txt')
      ]);
    });

    test('notifies when a subdirectory is replaced by a file', () async {
      writeFile('old');
      writeFile('new/file.txt');
      await startWatcher();

      renameDir('new', 'newer');
      renameFile('old', 'new');
      await inAnyOrder([
        isRemoveEvent('new/file.txt'),
        isAddEvent('newer/file.txt'),
        isRemoveEvent('old'),
        isAddEvent('new')
      ]);
    });

    test('emits events for many nested files added at once', () async {
      withPermutations((i, j, k) => writeFile('sub/sub-$i/sub-$j/file-$k.txt'));

      createDir('dir');
      await startWatcher(path: 'dir');
      renameDir('sub', 'dir/sub');

      await inAnyOrder(withPermutations(
          (i, j, k) => isAddEvent('dir/sub/sub-$i/sub-$j/file-$k.txt')));
    });

    test('emits events for many nested files removed at once', () async {
      withPermutations(
          (i, j, k) => writeFile('dir/sub/sub-$i/sub-$j/file-$k.txt'));

      createDir('dir');
      await startWatcher(path: 'dir');

      // Rename the directory rather than deleting it because native watchers
      // report a rename as a single DELETE event for the directory, whereas
      // they report recursive deletion with DELETE events for every file in the
      // directory.
      renameDir('dir/sub', 'sub');

      await inAnyOrder(withPermutations(
          (i, j, k) => isRemoveEvent('dir/sub/sub-$i/sub-$j/file-$k.txt')));
    });

    test('emits events for many nested files moved at once', () async {
      withPermutations(
          (i, j, k) => writeFile('dir/old/sub-$i/sub-$j/file-$k.txt'));

      createDir('dir');
      await startWatcher(path: 'dir');
      renameDir('dir/old', 'dir/new');

      await inAnyOrder(unionAll(withPermutations((i, j, k) {
        return {
          isRemoveEvent('dir/old/sub-$i/sub-$j/file-$k.txt'),
          isAddEvent('dir/new/sub-$i/sub-$j/file-$k.txt')
        };
      })));
    });

    test(
        'emits events for many nested files moved out then immediately back in',
        () async {
      withPermutations(
          (i, j, k) => writeFile('dir/sub/sub-$i/sub-$j/file-$k.txt'));

      await startWatcher(path: 'dir');

      renameDir('dir/sub', 'sub');
      renameDir('sub', 'dir/sub');

      if (isNative) {
        await inAnyOrder(withPermutations(
            (i, j, k) => isRemoveEvent('dir/sub/sub-$i/sub-$j/file-$k.txt')));
        await inAnyOrder(withPermutations(
            (i, j, k) => isAddEvent('dir/sub/sub-$i/sub-$j/file-$k.txt')));
      } else {
        // Polling watchers can't detect this as directory contents mtimes
        // aren't updated when the directory is moved.
        await expectNoEvents();
      }
    });

    test(
        'emits events for many files added at once in a subdirectory with the '
        'same name as a removed file', () async {
      writeFile('dir/sub');
      withPermutations((i, j, k) => writeFile('old/sub-$i/sub-$j/file-$k.txt'));
      await startWatcher(path: 'dir');

      deleteFile('dir/sub');
      renameDir('old', 'dir/sub');

      var events = withPermutations(
          (i, j, k) => isAddEvent('dir/sub/sub-$i/sub-$j/file-$k.txt'));
      events.add(isRemoveEvent('dir/sub'));
      await inAnyOrder(events);
    });

    test('subdirectory watching is robust against races', () async {
      // Make sandboxPath accessible to child isolates created by Isolate.run.
      final sandboxPath = d.sandbox;
      final dirNames = [for (var i = 0; i < 500; i++) 'dir$i'];
      await startWatcher();

      // Repeatedly create and delete subdirectories in attempt to trigger
      // a race.
      for (var i = 0; i < 10; i++) {
        for (var dir in dirNames) {
          createDir(dir);
        }
        await Isolate.run(() async {
          await Future.wait([
            for (var dir in dirNames)
              io.Directory('$sandboxPath/$dir').delete(),
          ]);
        });
      }
    });
  });

  test(
      'does not notify about the watched directory being deleted and '
      'recreated immediately before watching', () async {
    createDir('dir');
    writeFile('dir/old.txt');
    deleteDir('dir');
    createDir('dir');

    await startWatcher(path: 'dir');
    writeFile('dir/newer.txt');
    await expectAddEvent('dir/newer.txt');
  });

  test('does not suppress files with the same prefix as a directory', () async {
    // Regression test for https://github.com/dart-lang/watcher/issues/83
    writeFile('some_name.txt');

    await startWatcher();

    writeFile('some_name/some_name.txt');
    deleteFile('some_name.txt');

    await inAnyOrder([
      isAddEvent('some_name/some_name.txt'),
      isRemoveEvent('some_name.txt')
    ]);
  });
}
