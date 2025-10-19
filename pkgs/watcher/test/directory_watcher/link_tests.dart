// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

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

    writeLink(link: 'links/a.link', target: 'targets/a.target');

    await expectAddEvent('links/a.link');
  });

  test(
      'notifies when a link is replaced with a link to a different target '
      'with the same contents', () async {
    createDir('targets');
    createDir('links');
    writeFile('targets/a.target');
    writeFile('targets/b.target');
    writeLink(link: 'links/a.link', target: 'targets/a.target');
    await startWatcher(path: 'links');

    deleteLink('links/a.link');
    writeLink(link: 'links/a.link', target: 'targets/b.target');

    await expectModifyEvent('links/a.link');
  });

  test(
      'notifies when a link is replaced with a link to a different target '
      'with different contents', () async {
    writeFile('targets/a.target', contents: 'a');
    writeFile('targets/b.target', contents: 'b');
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

    // TODO(davidmorgan): reconcile differences.
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

    // TODO(davidmorgan): reconcile differences.
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

    await inAnyOrder(
        [isAddEvent('links/b.link'), isRemoveEvent('links/a.link')]);
  });

  test('notifies when a link to an empty directory is added', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    await startWatcher(path: 'links');

    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectAddEvent('links/a.link');
    } else {
      await expectNoEvents();
    }
  });

  test(
      'does not notify about directory contents '
      'when a link to a directory is added', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    writeFile('targets/a.targetdir/a.target');
    await startWatcher(path: 'links');

    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');

    // TODO(davidmorgan): reconcile differences.
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

    // TODO(davidmorgan): reconcile differences.
    if (!isNative || Platform.isLinux) {
      await expectAddEvent('links/a.link/a.txt');
    } else {
      await expectNoEvents();
    }
  });

  test(
      'notifies about linked directory contents when a directory with a linked '
      'subdirectory is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    await expectAddEvent('watched/links/a.link/a.txt');
  });

  test(
      'notifies about linked directory contents when a directory with a linked '
      'subdirectory containing a link loop is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    writeLink(
        link: 'targets/a.targetdir/cycle.link', target: 'targets/a.targetdir');
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    // TODO(davidmorgan): reconcile differences.
    if (isNative && (Platform.isLinux || Platform.isMacOS)) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle.link/cycle.link'),
      ]);
      await expectNoEvents();
    } else if (isNative && Platform.isWindows) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle.link'),
      ]);
      await expectNoEvents();
    } else if (!isNative && Platform.isWindows) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
      ]);
      await expectNoEvents();
    } else {
      assert(!isNative);
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle.link/a.txt'),
      ]);
      await expectNoEvents();
    }
  });

  test(
      'notifies about linked directory contents when a directory with a linked '
      'subdirectory containing two link loops is moved in', () async {
    createDir('targets');
    createDir('links');
    createDir('targets/a.targetdir');
    createDir('watched');
    writeFile('targets/a.targetdir/a.txt');
    writeLink(link: 'links/a.link', target: 'targets/a.targetdir');
    writeLink(
        link: 'targets/a.targetdir/cycle1.link', target: 'targets/a.targetdir');
    writeLink(
        link: 'targets/a.targetdir/cycle2.link', target: 'targets/a.targetdir');
    await startWatcher(path: 'watched');

    renameDir('links', 'watched/links');

    // TODO(davidmorgan): reconcile differences.
    if (isNative && (Platform.isLinux || Platform.isMacOS)) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link/cycle1.link'),
        isAddEvent('watched/links/a.link/cycle1.link/cycle2.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link/cycle2.link/cycle1.link'),
        isAddEvent('watched/links/a.link/cycle1.link/cycle2.link/cycle2.link'),
        isAddEvent('watched/links/a.link/cycle2.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle2.link/cycle1.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle2.link/cycle1.link/cycle1.link'),
        isAddEvent('watched/links/a.link/cycle2.link/cycle1.link/cycle2.link'),
        isAddEvent('watched/links/a.link/cycle2.link/cycle2.link'),
      ]);
      await expectNoEvents();
    } else if (isNative && Platform.isWindows) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link'),
        isAddEvent('watched/links/a.link/cycle2.link'),
      ]);
      await expectNoEvents();
    } else if (!isNative && Platform.isWindows) {
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
      ]);
      await expectNoEvents();
    } else {
      assert(!isNative);
      await inAnyOrder([
        isAddEvent('watched/links/a.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle1.link/cycle2.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle2.link/a.txt'),
        isAddEvent('watched/links/a.link/cycle2.link/cycle1.link/a.txt'),
      ]);
      await expectNoEvents();
    }
  });
}
