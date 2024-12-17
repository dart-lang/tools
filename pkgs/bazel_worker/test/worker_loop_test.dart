// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/testing.dart';
import 'package:test/test.dart';

void main() {
  group('SyncWorkerLoop', () {
    runTests(
      TestStdinSync.new,
      TestSyncWorkerConnection.new,
      TestSyncWorkerLoop.new,
    );
  });

  group('AsyncWorkerLoop', () {
    runTests(
      TestStdinAsync.new,
      TestAsyncWorkerConnection.new,
      TestAsyncWorkerLoop.new,
    );
  });

  group('SyncWorkerLoopWithPrint', () {
    runTests(
      TestStdinSync.new,
      TestSyncWorkerConnection.new,
      (TestSyncWorkerConnection connection) =>
          TestSyncWorkerLoop(connection, printMessage: 'Goodbye!'),
    );
  });

  group('AsyncWorkerLoopWithPrint', () {
    runTests(
      TestStdinAsync.new,
      TestAsyncWorkerConnection.new,
      (TestAsyncWorkerConnection connection) =>
          TestAsyncWorkerLoop(connection, printMessage: 'Goodbye!'),
    );
  });
}

void runTests<T extends TestWorkerConnection>(
  TestStdin Function() stdinFactory,
  T Function(Stdin, Stdout) workerConnectionFactory,
  TestWorkerLoop Function(T) workerLoopFactory,
) {
  late TestStdin stdinStream;
  late TestStdoutStream stdoutStream;
  late T connection;
  late TestWorkerLoop workerLoop;

  setUp(() {
    stdinStream = stdinFactory();
    stdoutStream = TestStdoutStream();
    connection = workerConnectionFactory(stdinStream, stdoutStream);
    workerLoop = workerLoopFactory(connection);
  });

  test('basic', () async {
    var request = WorkRequest(arguments: ['--foo=bar']);
    stdinStream.addInputBytes(protoToDelimitedBuffer(request));
    stdinStream.close();

    var response = WorkResponse(output: 'Hello World');
    workerLoop.enqueueResponse(response);

    // Make sure `print` never gets called in the parent zone.
    var printMessages = <String>[];
    await runZoned(
      () => workerLoop.run(),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {
          printMessages.add(message);
        },
      ),
    );
    expect(
      printMessages,
      isEmpty,
      reason: 'The worker loop should hide all print calls from the parent '
          'zone.',
    );

    expect(connection.responses, hasLength(1));
    expect(connection.responses[0], response);
    if (workerLoop.printMessage != null) {
      expect(
        response.output,
        endsWith(workerLoop.printMessage!),
        reason: 'Print messages should get appended to the response output.',
      );
    }

    // Check that a serialized version was written to std out.
    expect(stdoutStream.writes, hasLength(1));
    expect(stdoutStream.writes[0], protoToDelimitedBuffer(response));
  });

  test('Exception in the worker.', () async {
    var request = WorkRequest(arguments: ['--foo=bar']);
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

  test('Stops if stdin gives an error instead of EOF', () async {
    if (stdinStream is TestStdinSync) {
      // Reading will now cause an error as pendingBytes is empty.
      (stdinStream as TestStdinSync).pendingBytes.clear();
      await workerLoop.run();
    } else if (stdinStream is TestStdinAsync) {
      var done = Completer<void>();
      // ignore: avoid_dynamic_calls
      workerLoop.run().then((_) => done.complete(null));
      (stdinStream as TestStdinAsync).controller.addError('Error!!');
      await done.future;
    }
  });
}
