// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/driver.dart';
import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  var sdkPath = getSdkPath();
  var dart = p.join(sdkPath, 'bin', 'dart');
  runE2eTestForWorker('sync worker',
      () => Process.start(dart, [p.join('bin', 'sync_worker.dart')]));
  runE2eTestForWorker('async worker',
      () => Process.start(dart, [p.join('bin', 'async_worker.dart')]));
  runE2eTestForWorker(
      'async worker in isolate',
      () =>
          Process.start(dart, [p.join('bin', 'async_worker_in_isolate.dart')]));
}

void runE2eTestForWorker(String groupName, SpawnWorker spawnWorker) {
  BazelWorkerDriver driver;
  group(groupName, () {
    setUp(() {
      driver = BazelWorkerDriver(spawnWorker);
    });

    tearDown(() async {
      await driver.terminateWorkers();
    });

    test('single work request', () async {
      await _doRequests(driver, count: 1);
    });

    test('lots of requests', () async {
      await _doRequests(driver, count: 1000);
    });
  });
}

/// Runs [count] work requests through [driver], and asserts that they all
/// completed with the correct response.
Future _doRequests(BazelWorkerDriver driver, {int count}) async {
  count ??= 100;
  var requests = List.generate(count, (requestNum) {
    var request = WorkRequest();
    request.arguments.addAll(List.generate(requestNum, (argNum) => '$argNum'));
    return request;
  });
  var responses = await Future.wait(requests.map(driver.doWork));
  for (var i = 0; i < responses.length; i++) {
    var request = requests[i];
    var response = responses[i];
    expect(response.exitCode, EXIT_CODE_OK);
    expect(response.output, request.arguments.join('\n'));
  }
}
