// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import '../utils.dart';

void linkTests({required bool isNative}) {
  setUp(() async {
    writeFile('target.txt');
    writeLink(link: 'link.txt', target: 'target.txt');
  });

  for (var i = 0; i != runsPerTest; ++i) {
    _linkTests(isNative: isNative);
  }
}

void _linkTests({required bool isNative}) {
  test("doesn't notify if nothing is modified", () async {
    await startWatcher(path: 'link.txt');
    await expectNoEvents();
  });

  test('notifies when a link is overwritten with an identical file', () async {
    await startWatcher(path: 'link.txt');
    writeFile('link.txt');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectModifyEvent('link.txt');
    }
  });

  test('notifies when a link is overwritten with a different file', () async {
    await startWatcher(path: 'link.txt');
    writeFile('link.txt', contents: 'modified');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectModifyEvent('link.txt');
    }
  });

  test(
    'notifies when a link target is overwritten with an identical file',
    () async {
      await startWatcher(path: 'link.txt');
      writeFile('target.txt');

      await expectModifyEvent('link.txt');
    },
  );

  test('notifies when a link target is modified', () async {
    await startWatcher(path: 'link.txt');
    writeFile('target.txt', contents: 'modified');

    await expectModifyEvent('link.txt');
  });

  test('notifies when a link is removed', () async {
    await startWatcher(path: 'link.txt');
    deleteLink('link.txt');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectRemoveEvent('link.txt');
    }
  });

  test('notifies when a link target is removed', () async {
    await startWatcher(path: 'link.txt');
    deleteFile('target.txt');
    await expectRemoveEvent('link.txt');
  });

  test('notifies when a link target is modified multiple times', () async {
    await startWatcher(path: 'link.txt');

    writeFile('target.txt', contents: 'modified');

    await expectModifyEvent('link.txt');

    writeFile('target.txt', contents: 'modified again');

    await expectModifyEvent('link.txt');
  });

  test('notifies when a link is moved away', () async {
    await startWatcher(path: 'link.txt');
    renameLink('link.txt', 'new.txt');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectRemoveEvent('link.txt');
    }
  });

  test('notifies when a link target is moved away', () async {
    await startWatcher(path: 'link.txt');
    renameFile('target.txt', 'new.txt');
    await expectRemoveEvent('link.txt');
  });

  test('notifies when an identical file is moved over the link', () async {
    await startWatcher(path: 'link.txt');
    writeFile('old.txt');
    renameFile('old.txt', 'link.txt');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectModifyEvent('link.txt');
    }
  });

  test('notifies when an different file is moved over the link', () async {
    await startWatcher(path: 'link.txt');
    writeFile('old.txt', contents: 'modified');
    renameFile('old.txt', 'link.txt');

    // TODO(davidmorgan): reconcile differences.
    if (isNative) {
      await expectNoEvents();
    } else {
      await expectModifyEvent('link.txt');
    }
  });

  test('notifies when an identical file is moved over the target', () async {
    await startWatcher(path: 'link.txt');
    writeFile('old.txt');
    renameFile('old.txt', 'target.txt');

    await expectModifyEvent('link.txt');
  });

  test('notifies when a different file is moved over the target', () async {
    await startWatcher(path: 'link.txt');
    writeFile('old.txt', contents: 'modified');
    renameFile('old.txt', 'target.txt');

    await expectModifyEvent('link.txt');
  });
}
