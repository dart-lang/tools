// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../constants.dart';
import '../worker_protocol.pb.dart';
import 'driver_connection.dart';

typedef Future<Process> SpawnWorker();

/// A driver for talking to a bazel worker.
///
/// This allows you to use any binary that supports the bazel worker protocol in
/// the same way that bazel would, but from another dart process instead.
class BazelWorkerDriver {
  /// The maximum number of idle workers at any given time.
  final int _maxIdleWorkers;

  /// The maximum number of concurrent workers to run at any given time.
  final int _maxWorkers;

  /// The number of currently active workers.
  int get _numWorkers => _allWorkers.length;

  /// Idle worker processes.
  final _idleWorkers = <Process>[];

  /// All workers, even the ones that are in the process of being spawned.
  final _allWorkers = <FutureOr<Process>>[];

  /// Work requests that haven't been started yet.
  final _workQueue = new Queue<WorkRequest>();

  /// Factory method that spawns a worker process.
  final SpawnWorker _spawnWorker;

  BazelWorkerDriver(this._spawnWorker, {int maxIdleWorkers, int maxWorkers})
      : this._maxIdleWorkers = maxIdleWorkers ?? 4,
        this._maxWorkers = maxWorkers ?? 4;

  Future<WorkResponse> doWork(WorkRequest request) {
    var responseCompleter = new Completer<WorkResponse>();
    _responseCompleters[request] = responseCompleter;
    _workQueue.add(request);
    _runWorkQueue();
    return responseCompleter.future;
  }

  /// Calls `kill` on all worker processes.
  Future terminateWorkers() async {
    var existing = new List.from(_allWorkers);
    _allWorkers.clear();
    await Future.wait(existing.map((futureWorker) async {
      (await futureWorker).kill();
    }));
  }

  /// Runs as many items in [_workQueue] as possible given the number of
  /// available workers.
  ///
  /// Will spawn additional workers until [_maxWorkers] has been reached.
  ///
  /// This method synchronously drains the [_workQueue] and [_idleWorkers], but
  /// some tasks may not actually start right away if they need to wait for a
  /// worker to spin up.
  void _runWorkQueue() {
    // Bail out conditions, we will continue to call ourselves indefinitely
    // until one of these is met.
    if (_workQueue.isEmpty) return;
    if (_numWorkers == _maxWorkers && _idleWorkers.isEmpty) return;
    if (_numWorkers > _maxWorkers) {
      throw new StateError('Internal error, created to many workers. Please '
          'file a bug at https://github.com/dart-lang/bazel_worker/issues/new');
    }

    // At this point we definitely want to run a task, we just need to decide
    // whether or not we need to start up a new worker.
    var request = _workQueue.removeFirst();
    if (_idleWorkers.isNotEmpty) {
      _runWorker(_idleWorkers.removeLast(), request);
    } else {
      // No need to block here, we want to continue to synchronously drain the
      // work queue.
      var futureWorker = _spawnWorker();
      _allWorkers.add(futureWorker);
      futureWorker.then((worker) {
        // Somewhat ugly cleanup, we want to replace the `Future<Process>` in
        // `_allWorkers` with the real `Process` once we have it.
        _allWorkers.remove(futureWorker);
        _allWorkers.add(worker);

        // Set up the connection and run the worker.
        _workerConnections[worker] = new StdDriverConnection.forWorker(worker);
        _runWorker(worker, request);

        // Clean up things when the worker exits, and retry running the work
        // queue in case there is more work to be done.
        worker.exitCode.then((_) {
          _allWorkers.remove(worker);
          _runWorkQueue();
        });
      });
    }
    // Recursively calls itself until one of the bail out conditions are met.
    _runWorkQueue();
  }

  /// Sends [request] to [worker].
  ///
  /// Once the worker responds then it will be added back to the pool of idle
  /// workers.
  Future _runWorker(Process worker, WorkRequest request) async {
    try {
      var connection = _workerConnections[worker];
      connection.writeRequest(request);
      var response = await connection.readResponse();
      _responseCompleters[request].complete(response);

      // Do additional work if available.
      _idleWorkers.add(worker);
      _runWorkQueue();

      // If the worker wasn't immediately used we might have to many idle
      // workers now, kill one if necessary.
      if (_idleWorkers.length > _maxIdleWorkers) {
        // Note that whenever we spawn a worker we listen for its exit code
        // and clean it up so we don't need to do that here.
        var worker = _idleWorkers.removeLast();
        _allWorkers.remove(worker);
        worker.kill();
      }
    } catch (e, s) {
      // Note that we don't need to do additional cleanup here on failures. If
      // the worker dies that is already handled in a generic fashion, we just
      // need to make sure we complete with a valid response.
      if (!_responseCompleters[request].isCompleted) {
        var response = new WorkResponse()
          ..exitCode = EXIT_CODE_ERROR
          ..output = 'Error running worker:\n$e\n$s';
        _responseCompleters[request].complete(response);
      }
    }
  }
}

final _responseCompleters = new Expando<Completer<WorkResponse>>('response');
final _workerConnections = new Expando<DriverConnection>('connectin');
