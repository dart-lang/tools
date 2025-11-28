// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// ignore_for_file: unreachable_from_main

import 'dart:io';

import 'package:test/test.dart';

import 'client_simulator.dart';
import 'end_to_end_test_runner.dart';
import 'file_changer.dart';

/// End to end test using a [FileChanger] to change files then a
/// [ClientSimulator] that tracks state using a Watcher.
///
/// The tests pass if the [ClientSimulator] tracking matches what's actually on
/// disk.
///
/// `end_to_end_test_runner` can be run as a binary to try random file changes
/// until a failure, it outputs a log which can be turned into a test case here.
void endToEndTests() {
  // Random test to cover a wide range of cases.
  test('end to end test: random', timeout: const Timeout(Duration(minutes: 10)),
      () async {
    await runTest(name: 'random', repeats: 100);
  });

  // Specific test cases that have caught bugs.
  for (final testCase in testCases) {
    test('end to end test: ${testCase.name}',
        timeout: const Timeout(Duration(minutes: 5)), () async {
      await runTest(name: testCase.name, replayLog: testCase.log, repeats: 50);
    }, skip: testCase.skipOnLinux && Platform.isLinux);
  }
}

final testCases = [
  TestCase(
    'move directory in, move file over',
    '''
F create directory,a
F create,a/1,1
F create directory,b
F create,b/2,2
F move directory to new,a,b/a
F create directory,c
F create,c/3,3
F move file over file,b/2,b/a/1
''',
  ),
  TestCase(
    'move new file over recently-moved file',
    '''
F create directory,b/g
F create,b/g/67046,94
F create directory,d
F move directory to new,b,d/f
F wait
F create directory,a/j
F create,a/j/85244,308
F wait
F move file over file,a/j/85244,d/f/g/67046
''',
  ),
  TestCase(
    'move over, modify, delete in new directory',
    '''
F create,62543,809
F wait
F wait
F wait
F wait
F create directory,a
F create,a/63090,758
F move file over file,62543,a/63090
F modify,a/63090,439
F delete,a/63090
''',
  ),
];
