// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// ignore_for_file: unreachable_from_main

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart' as package_test;
import 'package:watcher/src/utils.dart';
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
///
/// To fix the seed, set [seed]. The failure message prints the seed, so this
/// can be used to run just the events that triggered the failure.
Future<void> _runTest({
  void Function(void Function())? addTearDown,
  Watcher Function({required String path})? createWatcher,
  void Function(String)? fail,
  void Function(String)? printOnFailure,
  bool endlessMode = false,
  int? seed,
}) async {
  addTearDown ??= package_test.addTearDown;
  createWatcher ??= utils.createWatcher;
  fail ??= package_test.fail;
  printOnFailure ??= package_test.printOnFailure;

  final temp = Directory.systemTemp.createTempSync();
  addTearDown(() => temp.deleteSync(recursive: true));

  // Turn on logging of the watchers.
  final log = <LogEntry>[];
  logForTesting = (message) => log.add(LogEntry('W $message'));

  // Create the watcher and [ClientSimulator].
  final watcher = createWatcher(path: temp.path);
  final client = await ClientSimulator.watch(
      watcher: watcher, log: (message) => log.add(LogEntry('C $message')));
  addTearDown(client.close);

  // 40 iterations of making changes, waiting for events to settle, and
  // checking for consistency.
  final changer = FileChanger(temp.path);
  for (var i = 0; endlessMode || i != 40; ++i) {
    final runSeed = seed ?? i;
    log.clear();
    if (endlessMode) stdout.write('.');
    for (final entity in temp.listSync()) {
      entity.deleteSync(recursive: true);
    }
    // File changes.
    log.addAll(await changer.changeFiles(times: 200, seed: runSeed));

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
      final logPath = p.join(logTemp.path, 'log.txt');

      // Sort the log entries by timestamp.
      log.sort();

      File(logPath).writeAsStringSync(log.map((m) => '$m\n').join(''));
      fail('''
Failed on run $i, seed $runSeed. Run in a loop with that seed using:

  dart test/directory_watcher/end_to_end_tests.dart $runSeed

Changes/watcher/client log: $logPath
''');
    }
  }
}

/// Main method for running the e2e test without `package:test`.
///
/// Optionally, pass the seed to run with as the only argument.
///
/// Exits on failure, or runs forever.
Future<void> main(List<String> arguments) async {
  final seed = arguments.isNotEmpty ? int.parse(arguments.first) : null;
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
      seed: seed,
    );
  } finally {
    for (final teardown in teardowns) {
      teardown();
    }
  }
}

/// Log entry with timestamp.
///
/// Because file events happen on a different isolate the merged log uses
/// timestamps to put entries in the correct order.
class LogEntry implements Comparable<LogEntry> {
  final DateTime timestamp;
  final String message;

  LogEntry(this.message) : timestamp = DateTime.now();

  @override
  int compareTo(LogEntry other) => timestamp.compareTo(other.timestamp);

  @override
  String toString() => message;
}
