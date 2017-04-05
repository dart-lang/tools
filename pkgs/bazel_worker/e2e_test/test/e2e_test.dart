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
  var sdkDir = getSdkDir();
  var dart = p.join(sdkDir.path, 'bin', 'dart');
  runE2eTestForWorker('sync worker',
      () => Process.start(dart, [p.join('bin', 'sync_worker.dart')]));
  runE2eTestForWorker('async worker',
      () => Process.start(dart, [p.join('bin', 'async_worker.dart')]));
}

void runE2eTestForWorker(String groupName, SpawnWorker spawnWorker) {
  BazelWorkerDriver driver;
  group(groupName, () {
    setUp(() {
      driver = new BazelWorkerDriver(spawnWorker);
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
  var requests = new List.generate(count, (requestNum) {
    var request = new WorkRequest();
    request.arguments
        .addAll(new List.generate(requestNum, (argNum) => '$argNum'));
    return request;
  });
  var responses = await Future.wait(requests.map(driver.doWork));
  for (int i = 0; i < responses.length; i++) {
    var request = requests[i];
    var response = responses[i];
    expect(response.exitCode, EXIT_CODE_OK);
    expect(response.output, request.arguments.join('\n'));
  }
}
