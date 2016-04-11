// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:bazel_worker/bazel_worker.dart';

export 'src/utils.dart' show protoToDelimitedBuffer;

/// A [Stdin] mock object.
class TestStdinStream implements Stdin {
  final Queue<int> pendingBytes = new Queue<int>();

  // Adds all the input bytes to this stream.
  void addInputBytes(List<int> bytes) {
    pendingBytes.addAll(bytes);
  }

  @override
  int readByteSync() {
    if (pendingBytes.isEmpty) {
      return -1;
    } else {
      return pendingBytes.removeFirst();
    }
  }

  @override
  void noSuchMethod(Invocation invocation) {
    throw new StateError('Unexpected invocation $invocation');
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
    throw new StateError('Unexpected invocation $invocation');
  }
}

/// A [StdWorkerConnection] which records its responses.
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
class TestSyncWorkerLoop extends SyncWorkerLoop  {
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
