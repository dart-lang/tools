// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:bazel_worker/bazel_worker.dart';

export 'src/utils.dart' show protoToDelimitedBuffer;

/// A [Stdin] mock object.
///
/// Note: When using this with an [AsyncWorkerLoop] you must call [close] in
/// order for the loop to exit properly.
class TestStdinStream implements Stdin {
  /// Pending bytes to be delivered synchronously.
  final Queue<int> pendingBytes = new Queue<int>();

  /// Controls the stream for async delivery of bytes.
  final StreamController _controller = new StreamController();

  /// Adds all the [bytes] to this stream.
  void addInputBytes(List<int> bytes) {
    pendingBytes.addAll(bytes);
    _controller.add(bytes);
  }

  /// Closes this stream. This is necessary for the [AsyncWorkerLoop] to exit.
  Future close() => _controller.close();

  @override
  int readByteSync() {
    if (pendingBytes.isEmpty) {
      return -1;
    } else {
      return pendingBytes.removeFirst();
    }
  }

  @override
  StreamSubscription<List<int>> listen(onData(List<int> bytes),
      {Function onError, void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError) as StreamSubscription<List<int>>;
  }

  @override
  void noSuchMethod(Invocation invocation) {
    throw new StateError('Unexpected invocation ${invocation.memberName}.');
  }
}

/// A [Stdout] mock object.
class TestStdoutStream implements Stdout {
  final List<List<int>> writes = <List<int>>[];

  @override
  void add(List<int> bytes) {
    writes.add(bytes);
  }

  @override
  void noSuchMethod(Invocation invocation) {
    throw new StateError('Unexpected invocation ${invocation.memberName}.');
  }
}

/// A [StdSyncWorkerConnection] which records its responses.
class TestSyncWorkerConnection extends StdSyncWorkerConnection {
  final List<WorkResponse> responses = <WorkResponse>[];

  TestSyncWorkerConnection(Stdin stdinStream, Stdout stdoutStream)
      : super(stdinStream: stdinStream, stdoutStream: stdoutStream);

  @override
  void writeResponse(WorkResponse response) {
    super.writeResponse(response);
    responses.add(response);
  }
}

/// A [SyncWorkerLoop] for testing.
class TestSyncWorkerLoop extends SyncWorkerLoop {
  final List<WorkRequest> requests = <WorkRequest>[];
  final Queue<WorkResponse> _responses = new Queue<WorkResponse>();

  TestSyncWorkerLoop(SyncWorkerConnection connection)
      : super(connection: connection);

  @override
  WorkResponse performRequest(WorkRequest request) {
    requests.add(request);
    return _responses.removeFirst();
  }

  /// Adds [response] to the queue. These will be returned from
  /// [performResponse] in the order they are added, otherwise it will throw
  /// if the queue is empty.
  void enqueueResponse(WorkResponse response) {
    _responses.addLast(response);
  }
}

/// A [StdAsyncWorkerConnection] which records its responses.
class TestAsyncWorkerConnection extends StdAsyncWorkerConnection {
  final List<WorkResponse> responses = <WorkResponse>[];

  TestAsyncWorkerConnection(
      Stream<List<int>> inputStream, StreamSink<List<int>> outputStream)
      : super(inputStream: inputStream, outputStream: outputStream);

  @override
  void writeResponse(WorkResponse response) {
    super.writeResponse(response);
    responses.add(response);
  }
}

/// A [AsyncWorkerLoop] for testing.
class TestAsyncWorkerLoop extends AsyncWorkerLoop {
  final List<WorkRequest> requests = <WorkRequest>[];
  final Queue<WorkResponse> _responses = new Queue<WorkResponse>();

  TestAsyncWorkerLoop(AsyncWorkerConnection connection)
      : super(connection: connection);

  @override
  Future<WorkResponse> performRequest(WorkRequest request) async {
    requests.add(request);
    return _responses.removeFirst();
  }

  /// Adds [response] to the queue. These will be returned from
  /// [performResponse] in the order they are added, otherwise it will throw
  /// if the queue is empty.
  void enqueueResponse(WorkResponse response) {
    _responses.addLast(response);
  }
}
