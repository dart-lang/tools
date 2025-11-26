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
import 'end_to_end_tests.dart';
import 'file_changer.dart';

/// Runs the test with [name] for logging.
///
/// To run without `package:test`, pass [addTearDown], [createWatcher], [fail]
/// and [printOnFailure] replacements.
///
/// Runs [repeats] times, by default 50. Set to -1 to run until failure.
///
/// By default, runs through a fixed series of pseudo-random test cases. Or,
/// pass [fixSeed] to run at a fixed seed. Or, pass [replayLog] to replay from a
/// test log.
Future<void> runTest({
  required String name,
  void Function(void Function())? addTearDown,
  Watcher Function({required String path})? createWatcher,
  void Function(String)? fail,
  void Function(String)? printOnFailure,
  int repeats = 50,
  int? fixSeed,
  String? replayLog,
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

  // Making changes, waiting for events to settle, check for consistency.
  final changer = FileChanger(temp.path);
  for (var i = 0; i != repeats; ++i) {
    log.clear();
    if (repeats < 0) stdout.write('.');
    for (final entity in temp.listSync()) {
      entity.deleteSync(recursive: true);
    }

    // File changes.
    int? seed;
    if (replayLog == null) {
      seed ??= fixSeed ?? i;
      log.addAll(await changer.changeFiles(times: 200, seed: seed));
    } else {
      log.addAll(await changer.replayLog(replayLog));
    }

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
      if (repeats < 0) print('');
      client.verify(printOnFailure: printOnFailure);
      // Write the file operations before the failure to a log, fail the test.
      final logTemp = Directory.systemTemp.createTempSync();
      final logPath = p.join(logTemp.path, 'log.txt');

      // Sort the log entries by timestamp.
      log.sort();

      File(logPath).writeAsStringSync(log.map((m) => '$m\n').join(''));
      final failMessage = StringBuffer('\n');

      if (seed != null) {
        failMessage.write('''
Failed `$name` on run $i. Run in a loop with that seed using:

  dart test/directory_watcher/end_to_end_test_runner.dart seed $seed
''');
      } else {
        failMessage.write('''
Failed `$name` on run $i.
''');
      }

      failMessage.write('''

Changes/watcher/client log: $logPath
''');

      fail(failMessage.toString());
    }
  }
}

/// Main method for running the e2e test without `package:test`.
///
/// By default runs endlessly with seeds starting at 0.
///
/// Pass `seed <number>` to fix the seed.
///
/// Pass `replay` to run endlessly with hardcoded test cases from
/// `end_to_end_tests.dart`.
///
/// Exits on failure, or runs forever.
Future<void> main(List<String> arguments) async {
  final command = arguments.isEmpty ? null : arguments[0];
  final fixSeed = command == 'seed' ? int.parse(arguments[1]) : null;
  final replay = command == 'replay';

  final teardowns = <void Function()>[];
  try {
    if (replay) {
      while (true) {
        stdout.write('.');
        for (final testCase in testCases) {
          await runTest(
            name: testCase.name,
            addTearDown: teardowns.add,
            createWatcher: ({required String path}) => DirectoryWatcher(path),
            fail: (message) {
              print(message);
              exit(1);
            },
            printOnFailure: print,
            // Repeat a few times before moving onto the next test case to get
            // any effect of multiple consecutive runs.
            repeats: 3,
            replayLog: testCase.log,
          );
        }
      }
    } else {
      await runTest(
        name: fixSeed == null ? 'random' : 'fixed seed $fixSeed',
        addTearDown: teardowns.add,
        createWatcher: ({required String path}) => DirectoryWatcher(path),
        fail: (message) {
          print(message);
          exit(1);
        },
        printOnFailure: print,
        repeats: -1,
        fixSeed: fixSeed,
      );
    }
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

/// Test case using log replay.
class TestCase {
  final String name;
  final String log;
  final bool skipOnLinux;

  TestCase(this.name, this.log, {this.skipOnLinux = false});
}
