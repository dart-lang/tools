// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:test/test.dart';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/driver.dart';

void main() {
  BazelWorkerDriver driver;

  group('basic driver', () {
    test('can run a single request', () async {
      await _doRequests(count: 1);
      await _doRequests(count: 1);
    });

    test('can run multiple batches of requests through multiple workers',
        () async {
      var maxWorkers = 4;
      var maxIdleWorkers = 2;
      driver = BazelWorkerDriver(MockWorker.spawn,
          maxWorkers: maxWorkers, maxIdleWorkers: maxIdleWorkers);
      for (var i = 0; i < 10; i++) {
        await _doRequests(driver: driver);
        expect(MockWorker.liveWorkers.length, maxIdleWorkers);
        // No workers should be killed while there is ongoing work, but they
        // should be cleaned up once there isn't any more work to do.
        expect(MockWorker.deadWorkers.length,
            (maxWorkers - maxIdleWorkers) * (i + 1));
      }
    });

    test('can run multiple requests through one worker', () async {
      var maxWorkers = 1;
      var maxIdleWorkers = 1;
      driver = BazelWorkerDriver(MockWorker.spawn,
          maxWorkers: maxWorkers, maxIdleWorkers: maxIdleWorkers);
      for (var i = 0; i < 10; i++) {
        await _doRequests(driver: driver);
        expect(MockWorker.liveWorkers.length, 1);
        expect(MockWorker.deadWorkers.length, 0);
      }
    });

    test('can run one request through multiple workers', () async {
      driver =
          BazelWorkerDriver(MockWorker.spawn, maxWorkers: 4, maxIdleWorkers: 4);
      for (var i = 0; i < 10; i++) {
        await _doRequests(driver: driver, count: 1);
        expect(MockWorker.liveWorkers.length, 1);
        expect(MockWorker.deadWorkers.length, 0);
      }
    });

    test('can run with maxIdleWorkers == 0', () async {
      var maxWorkers = 4;
      driver = BazelWorkerDriver(MockWorker.spawn,
          maxWorkers: maxWorkers, maxIdleWorkers: 0);
      for (var i = 0; i < 10; i++) {
        await _doRequests(driver: driver);
        expect(MockWorker.liveWorkers.length, 0);
        expect(MockWorker.deadWorkers.length, maxWorkers * (i + 1));
      }
    });

    test('trackWork gets invoked when a worker is actually ready', () async {
      var maxWorkers = 2;
      driver = BazelWorkerDriver(MockWorker.spawn, maxWorkers: maxWorkers);
      var tracking = <Future>[];
      await _doRequests(
          driver: driver,
          count: 10,
          trackWork: (Future response) {
            // We should never be tracking more than `maxWorkers` jobs at a time.
            expect(tracking.length, lessThan(maxWorkers));
            tracking.add(response);
            response.then((_) => tracking.remove(response));
          });
    });

    group('failing workers', () {
      /// A driver which spawns [numBadWorkers] failing workers and then good
      /// ones after that, and which will retry [maxRetries] times.
      void createDriver({int maxRetries = 2, int numBadWorkers = 2}) {
        var numSpawned = 0;
        driver = BazelWorkerDriver(
            () async => MockWorker(workerLoopFactory: (MockWorker worker) {
                  var connection = StdAsyncWorkerConnection(
                      inputStream: worker._stdinController.stream,
                      outputStream: worker._stdoutController.sink);
                  if (numSpawned < numBadWorkers) {
                    numSpawned++;
                    return ThrowingMockWorkerLoop(
                        worker, MockWorker.responseQueue, connection);
                  } else {
                    return MockWorkerLoop(MockWorker.responseQueue,
                        connection: connection);
                  }
                }),
            maxRetries: maxRetries);
      }

      test('should retry up to maxRetries times', () async {
        createDriver();
        var expectedResponse = WorkResponse();
        MockWorker.responseQueue.addAll([null, null, expectedResponse]);
        var actualResponse = await driver.doWork(WorkRequest());
        // The first 2 null responses are thrown away, and we should get the
        // third one.
        expect(actualResponse, expectedResponse);

        expect(MockWorker.deadWorkers.length, 2);
        expect(MockWorker.liveWorkers.length, 1);
      });

      test('should fail if it exceeds maxRetries failures', () async {
        createDriver(maxRetries: 2, numBadWorkers: 3);
        MockWorker.responseQueue.addAll([null, null, WorkResponse()]);
        var actualResponse = await driver.doWork(WorkRequest());
        // Should actually get a bad response.
        expect(actualResponse.exitCode, 15);
        expect(
            actualResponse.output,
            'Invalid response from worker, this probably means it wrote '
            'invalid output or died.');

        expect(MockWorker.deadWorkers.length, 3);
      });
    });

    tearDown(() async {
      await driver?.terminateWorkers();
      expect(MockWorker.liveWorkers, isEmpty);
      MockWorker.deadWorkers.clear();
      MockWorker.responseQueue.clear();
    });
  });
}

/// Runs [count] of fake work requests through [driver], and asserts that they
/// all completed.
Future _doRequests(
    {BazelWorkerDriver driver,
    int count,
    Function(Future<WorkResponse>) trackWork}) async {
  // If we create a driver, we need to make sure and terminate it.
  var terminateDriver = driver == null;
  driver ??= BazelWorkerDriver(MockWorker.spawn);
  count ??= 100;
  terminateDriver ??= true;
  var requests = List.generate(count, (_) => WorkRequest());
  var responses = List.generate(count, (_) => WorkResponse());
  MockWorker.responseQueue.addAll(responses);
  var actualResponses = await Future.wait(
      requests.map((request) => driver.doWork(request, trackWork: trackWork)));
  expect(actualResponses, unorderedEquals(responses));
  if (terminateDriver) await driver.terminateWorkers();
}

/// A mock worker loop that returns work responses from the provided list.
///
/// Throws if it runs out of responses.
class MockWorkerLoop extends AsyncWorkerLoop {
  final Queue<WorkResponse> _responseQueue;

  MockWorkerLoop(this._responseQueue, {AsyncWorkerConnection connection})
      : super(connection: connection);

  @override
  Future<WorkResponse> performRequest(WorkRequest request) async {
    print('Performing request $request');
    return _responseQueue.removeFirst();
  }
}

/// A mock worker loop with a custom `run` function that throws.
class ThrowingMockWorkerLoop extends MockWorkerLoop {
  final MockWorker _mockWorker;

  ThrowingMockWorkerLoop(this._mockWorker, Queue<WorkResponse> responseQueue,
      AsyncWorkerConnection connection)
      : super(responseQueue, connection: connection);

  /// Run the worker loop. The returned [Future] doesn't complete until
  /// [connection#readRequest] returns `null`.
  @override
  Future run() async {
    while (true) {
      var request = await connection.readRequest();
      if (request == null) break;
      await performRequest(request);
      _mockWorker.kill();
    }
  }
}

/// A mock worker process.
///
/// Items in [responseQueue] will be returned in order based on requests.
///
/// If there are no items left in [responseQueue] then it will throw.
class MockWorker implements Process {
  /// Spawns a new [MockWorker].
  static Future<MockWorker> spawn() async => MockWorker();

  /// Static queue of pending responses, these are shared by all workers.
  ///
  /// If this is empty and a request is received then it will throw.
  static final responseQueue = Queue<WorkResponse>();

  /// Static list of all live workers.
  static final liveWorkers = <MockWorker>[];

  /// Static list of all the dead workers.
  static final deadWorkers = <MockWorker>[];

  /// Standard constructor, creates a [WorkerLoop] from [workerLoopFactory] or
  /// a [MockWorkerLoop] if no factory is provided.
  MockWorker({WorkerLoop Function(MockWorker) workerLoopFactory}) {
    liveWorkers.add(this);
    var workerLoop = workerLoopFactory != null
        ? workerLoopFactory(this)
        : MockWorkerLoop(responseQueue,
            connection: StdAsyncWorkerConnection(
                inputStream: _stdinController.stream,
                outputStream: _stdoutController.sink));
    workerLoop.run();
  }

  @override
  Future<int> get exitCode => throw UnsupportedError('Not needed.');

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;
  final _stdoutController = StreamController<List<int>>();

  @override
  Stream<List<int>> get stderr => _stderrController.stream;
  final _stderrController = StreamController<List<int>>();

  @override
  IOSink get stdin {
    _stdin ??= IOSink(_stdinController.sink);
    return _stdin;
  }

  IOSink _stdin;
  final _stdinController = StreamController<List<int>>();

  @override
  int get pid => throw UnsupportedError('Not needed.');

  @override
  bool kill([processSignal = ProcessSignal.sigterm, int exitCode = 0]) {
    if (_killed) return false;
    () async {
      await _stdoutController.close();
      await _stderrController.close();
      await _stdinController.close();
    }();
    deadWorkers.add(this);
    liveWorkers.remove(this);
    return true;
  }

  final _killed = false;
}
