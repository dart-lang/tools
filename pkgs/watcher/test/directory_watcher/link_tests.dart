// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import '../utils.dart';

void linkTests({required bool isNative}) {
  for (var i = 0; i != runsPerTest; ++i) {
    _linkTests(isNative: isNative);
  }
}

void _linkTests({required bool isNative}) {
  test('notifies when a link is added', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    await startWatcher(path: 'links');

    writeLink(
      link: 'links/a.link',
      target: 'targets/a.target',
      unawaitedAsync: true,
    );

    await expectAddEvent('links/a.link');
  });

  test('notifies when a link is replaced with a link to a different target '
      'with the same contents', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    sleepUntilNewModificationTime();
    writeFile('targets/b.target');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');

    deleteLink('links/a.link');
    writeLink(link: 'links/a.link', target: 'targets/b.target');

    await expectModifyEvent('links/a.link');
  });

  test('notifies when a link is replaced with a link to a different target '
      'with different contents', () async {
    writeFile('targets/a.target', contents: 'a');
    writeFile('targets/b.target', contents: 'ab');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');

    deleteLink('links/a.link');
    writeLink(link: 'links/a.link', target: 'targets/b.target');

    await expectModifyEvent('links/a.link');
  });

  test('does not notify when a link target is modified', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');
    writeFile('targets/a.target', contents: 'modified');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectModifyEvent('links/a.link');
    }
  });

  test('does not notify when a link target is removed', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');

    deleteFile('targets/a.target');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectRemoveEvent('links/a.link');
    }
  });

  test('notifies when a link is moved within the watched directory', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');

    renameLink('links/a.link', 'links/b.link');

    await inAnyOrder([
      isAddEvent('links/b.link'),
      isRemoveEvent('links/a.link'),
    ]);
  });

  test('notifies when a link to an empty directory is added', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    await startWatcher(path: 'links');

    writeLink(
      link: 'links/a.link',
      target: 'targets/a.targetdir',
      unawaitedAsync: true,
    );

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('links/a.link');
    } else {
      await expectNoEvents();
    }
  });

  test('does not notify about directory contents '
      'when a link to a directory is added', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    writeFile('targets/a.targetdir/a.target');
    await startWatcher(path: 'links');

    writeLink(
      link: 'links/a.link',
      target: 'targets/a.targetdir',
      unawaitedAsync: true,
    );

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('links/a.link');
    } else {
      await expectAddEvent('links/a.link/a.target');
    }
  });

  test('notifies when a file is added to a linked directory', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    await startWatcher(path: 'links');

    writeFile('targets/a.targetdir/a.txt');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectAddEvent('links/a.link/a.txt');
    }
  });

  test('notifies when a file is added to a newly linked directory', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    await startWatcher(path: 'links');

    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    writeFile('targets/a.targetdir/a.txt');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('links/a.link');
    } else {
      await expectAddEvent('links/a.link/a.txt');
    }
  });

  test('notifies about linked directory contents when a directory with a '
      'linked subdirectory is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('watched/links/a.link');
    } else {
      await expectAddEvent('watched/links/a.link/a.txt');
    }
  });

  test('notifies about linked directory contents when a directory with a '
      'linked subdirectory containing a link loop is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    writeLink(
      link: 'targets/a.targetdir/cycle.link',
      target: 'targets/a.targetdir',
    );
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('watched/links/a.link');
    } else {
      await expectAddEvent('watched/links/a.link/a.txt');
    }
    await expectNoEvents();
  });

  test('notifies about linked directory contents when a directory with a '
      'linked subdirectory containing two link loops is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    writeLink(
      link: 'targets/a.targetdir/cycle1.link',
      target: 'targets/a.targetdir',
    );
    writeLink(
      link: 'targets/a.targetdir/cycle2.link',
      target: 'targets/a.targetdir',
    );
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    // Native watchers treat links as files, polling watcher polls through them.
    if (isNative) {
      await expectAddEvent('watched/links/a.link');
    } else {
      await expectAddEvent('watched/links/a.link/a.txt');
    }
    await expectNoEvents();
  });

  test('is not slow in a directory with many link loops', () async {
    createDir('links');
    writeLink(link: 'links/a/cycle1.link', target: 'links/a');
    writeLink(link: 'links/a/cycle2.link', target: 'links/a');
    writeLink(link: 'links/a/cycle3.link', target: 'links/a');
    writeLink(link: 'links/a/cycle4.link', target: 'links/a');
    writeLink(link: 'links/a/cycle5.link', target: 'links/a');
    writeLink(link: 'links/a/cycle6.link', target: 'links/a');
    writeLink(link: 'links/a/cycle7.link', target: 'links/a');

    final stopwatch = Stopwatch()..start();
    await startWatcher(path: 'links');
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });
}
