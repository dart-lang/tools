// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// ignore_for_file: unreachable_from_main

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart' as package_test;
import 'package:watcher/watcher.dart';

import '../utils.dart' as utils;
import 'client_simulator.dart';
import 'file_changer.dart';

/// End to end test using a [FileChanger] that randomly changes files, then a
/// [ClientSimulator] that tracks state using a Watcher.
///
/// The test passes if the [ClientSimulator] tracking matches what's actually on
/// disk.
void endToEndTests() {
  package_test.test('end to end test',
      timeout: const package_test.Timeout(Duration(minutes: 5)), () async {
    await _runTest();
  });
}

/// Runs the test.
///
/// To run without `package:test`, pass [addTearDown], [createWatcher], [fail]
/// and [printOnFailure] replacements.
///
/// To run until failure, set [endlessMode] to `true`.
Future<void> _runTest({
  void Function(void Function())? addTearDown,
  Watcher Function({required String path})? createWatcher,
  void Function(String)? fail,
  void Function(String)? printOnFailure,
  bool endlessMode = false,
}) async {
  addTearDown ??= package_test.addTearDown;
  createWatcher ??= utils.createWatcher;
  fail ??= package_test.fail;
  printOnFailure ??= package_test.printOnFailure;

  final temp = Directory.systemTemp.createTempSync();
  addTearDown(() => temp.deleteSync(recursive: true));

  // Create the watcher and [ClientSimulator].
  final watcher = createWatcher(path: temp.path);
  final client = await ClientSimulator.watch(
      watcher: watcher, printOnFailure: printOnFailure);
  addTearDown(client.close);

  // 40 iterations of making changes, waiting for events to settle, and
  // checking for consistency.
  final changer = FileChanger(temp.path);
  for (var i = 0; endlessMode || i != 40; ++i) {
    if (endlessMode) stdout.write('.');
    for (final entity in temp.listSync()) {
      entity.deleteSync(recursive: true);
    }
    // File changes.
    final messages = await changer.changeFiles(times: 200);

    // Give time for events to arrive. To allow tests to run quickly when the
    // events are handled quickly, poll and continue if verification passes.
    var succeeded = false;
    for (var waits = 0; waits != 20; ++waits) {
      if (client.verify()) {
        succeeded = true;
        break;
      }
      await client.waitForNoEvents(const Duration(milliseconds: 100));
    }

    // Fail the test if still not consistent.
    if (!succeeded) {
      if (endlessMode) print('');
      client.verify(printOnFailure: printOnFailure);
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
}

/// Main method for running the e2e test without `package:test`.
///
/// Exits on failure, or runs forever.
Future<void> main() async {
  final teardowns = <void Function()>[];
  try {
    await _runTest(
      addTearDown: teardowns.add,
      createWatcher: ({required String path}) => DirectoryWatcher(path),
      fail: (message) {
        print(message);
        exit(1);
      },
      printOnFailure: print,
      endlessMode: true,
    );
  } finally {
    for (final teardown in teardowns) {
      teardown();
    }
  }
}
