// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/testing.dart';

void main() {
  group('SyncWorkerLoop', () {
    runTests(
        () => new TestStdinSync(),
        (Stdin stdinStream, Stdout stdoutStream) =>
            new TestSyncWorkerConnection(stdinStream, stdoutStream),
        (TestSyncWorkerConnection connection) =>
            new TestSyncWorkerLoop(connection));
  });

  group('AsyncWorkerLoop', () {
    runTests(
        () => new TestStdinAsync(),
        (Stdin stdinStream, Stdout stdoutStream) =>
            new TestAsyncWorkerConnection(stdinStream, stdoutStream),
        (TestAsyncWorkerConnection connection) =>
            new TestAsyncWorkerLoop(connection));
  });
}

void runTests/*<T extends TestWorkerConnection>*/(
    TestStdin stdinFactory(),
    /*=T*/ workerConnectionFactory(Stdin stdin, Stdout stdout),
    TestWorkerLoop workerLoopFactory(/*=T*/ connection)) {
  TestStdin stdinStream;
  TestStdoutStream stdoutStream;
  var /*=T*/ connection;
  TestWorkerLoop workerLoop;

  setUp(() {
    stdinStream = stdinFactory();
    stdoutStream = new TestStdoutStream();
    connection = workerConnectionFactory(stdinStream, stdoutStream);
    workerLoop = workerLoopFactory(connection);
  });

  test('basic', () async {
    var request = new WorkRequest();
    request.arguments.addAll(['--foo=bar']);
    stdinStream.addInputBytes(protoToDelimitedBuffer(request));
    stdinStream.close();

    var response = new WorkResponse()..output = 'Hello World';
    workerLoop.enqueueResponse(response);
    await workerLoop.run();

    expect(connection.responses, hasLength(1));
    expect(connection.responses[0], response);

    // Check that a serialized version was written to std out.
    expect(stdoutStream.writes, hasLength(1));
    expect(stdoutStream.writes[0], protoToDelimitedBuffer(response));
  });

  test('Exception in the worker.', () async {
    var request = new WorkRequest();
    request.arguments.addAll(['--foo=bar']);
    stdinStream.addInputBytes(protoToDelimitedBuffer(request));
    stdinStream.close();

    // Didn't enqueue a response, so this will throw inside of `performRequest`.
    await workerLoop.run();

    expect(connection.responses, hasLength(1));
    var response = connection.responses[0];
    expect(response.exitCode, EXIT_CODE_ERROR);

    // Check that a serialized version was written to std out.
    expect(stdoutStream.writes, hasLength(1));
    expect(stdoutStream.writes[0], protoToDelimitedBuffer(response));
  });

  test('Stops at EOF', () async {
    stdinStream.addInputBytes([-1]);
    stdinStream.close();
    await workerLoop.run();
  });
}
