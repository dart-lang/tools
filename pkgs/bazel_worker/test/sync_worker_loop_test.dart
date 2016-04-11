// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/testing.dart';

void main() {
  TestStdinStream stdinStream;
  TestStdoutStream stdoutStream;
  TestSyncWorkerConnection connection;
  TestSyncWorkerLoop workerLoop;

  setUp(() {
    stdinStream = new TestStdinStream();
    stdoutStream = new TestStdoutStream();
    connection = new TestSyncWorkerConnection(stdinStream, stdoutStream);
    workerLoop = new TestSyncWorkerLoop(connection);
  });

  test('basic', () {
    var request = new WorkRequest();
    request.arguments.addAll(['--foo=bar']);
    stdinStream.addInputBytes(protoToDelimitedBuffer(request));

    var response = new WorkResponse()..output = 'Hello World';
    workerLoop.enqueueResponse(response);
    workerLoop.run();

    expect(connection.responses, hasLength(1));
    expect(connection.responses[0], response);

    // Check that a serialized version was written to std out.
    expect(stdoutStream.writes, hasLength(1));
    expect(stdoutStream.writes[0], protoToDelimitedBuffer(response));
  });

  test('Exception in the worker.', () {
    var request = new WorkRequest();
    request.arguments.addAll(['--foo=bar']);
    stdinStream.addInputBytes(protoToDelimitedBuffer(request));

    // Didn't enqueue a response, so this will throw inside of `performRequest`.
    workerLoop.run();

    expect(connection.responses, hasLength(1));
    var response = connection.responses[0];
    expect(response.exitCode, EXIT_CODE_ERROR);

    // Check that a serialized version was written to std out.
    expect(stdoutStream.writes, hasLength(1));
    expect(stdoutStream.writes[0], protoToDelimitedBuffer(response));
  });

  test('Stops at EOF', () {
    stdinStream.addInputBytes([-1]);
    workerLoop.run();
  });
}
