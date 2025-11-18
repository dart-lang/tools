// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../utils.dart';
import 'client_simulator.dart';
import 'file_changer.dart';

/// End to end test using a [FileChanger] that randomly changes files, then a
/// [ClientSimulator] that tracks state using a Watcher.
///
/// The test passes if the [ClientSimulator] tracking matches what's actually on
/// disk.
///
/// Fails on Linux due to https://github.com/dart-lang/tools/issues/2228.
///
/// Fails sometimes on Windows due to
/// https://github.com/dart-lang/tools/issues/2234.
void endToEndTests({required bool isNative}) {
  test('end to end test', timeout: const Timeout(Duration(minutes: 5)),
      () async {
    final temp = Directory.systemTemp.createTempSync();
    addTearDown(() => temp.deleteSync(recursive: true));

    // Create the watcher and [ClientSimulator].
    final watcher = createWatcher(path: temp.path);
    final client = await ClientSimulator.watch(watcher);
    addTearDown(client.close);

    // 20 iterations of making changes, waiting for events to settle, and
    // checking for consistency.
    final changer = FileChanger(temp.path);
    for (var i = 0; i != 40; ++i) {
      for (final entity in temp.listSync()) {
        entity.deleteSync(recursive: true);
      }
      // File changes.
      final messages = await changer.changeFiles(times: 200);

      // Give time for events to arrive. To allow tests to run quickly when the
      // events are handled quickly, poll and continue if verification passes.
      for (var waits = 0; waits != 20; ++waits) {
        if (client.verify(log: false)) {
          break;
        }
        await client.waitForNoEvents(const Duration(milliseconds: 100));
      }

      // Verify for real and fail the test if still not consistent.
      if (!client.verify(log: true)) {
        // Write the file operations before the failure to a log, fail the test.
        final logTemp = Directory.systemTemp.createTempSync();
        final fileChangesLogPath = p.join(logTemp.path, 'changes.txt');
        File(fileChangesLogPath)
            .writeAsStringSync(messages.map((m) => '$m\n').join(''));
        final clientLogPath = p.join(logTemp.path, 'client.txt');
        File(clientLogPath)
            .writeAsStringSync(client.messages.map((m) => '$m\n').join(''));
        fail('''
Failed on run $i.
Files changes: $fileChangesLogPath
Client log: $clientLogPath''');
      }
    }
  });
}
