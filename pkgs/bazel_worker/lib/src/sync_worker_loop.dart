// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'constants.dart';
import 'sync_message_grouper.dart';
import 'utils.dart';
import 'worker_connection.dart';
import 'worker_loop.dart';
import 'worker_protocol.pb.dart';

/// Connection between a worker and input / output.
abstract class SyncWorkerConnection implements WorkerConnection {
  /// Read a new [WorkRequest]. Returns [null] when there are no more requests.
  WorkRequest readRequest();

  /// Write the given [response] as bytes to the output.
  void writeResponse(WorkResponse response);
}

/// Persistent Bazel worker loop.
///
/// Extend this class and implement the `performRequest` method.
abstract class SyncWorkerLoop implements WorkerLoop {
  final SyncWorkerConnection connection;

  SyncWorkerLoop({SyncWorkerConnection connection})
      : this.connection = connection ?? new StdSyncWorkerConnection();

  /// Perform a single [WorkRequest], and return a [WorkResponse].
  WorkResponse performRequest(WorkRequest request);

  /// Run the worker loop. Blocks until [connection#readRequest] returns `null`.
  void run() {
    while (true) {
      WorkResponse response;
      try {
        var request = connection.readRequest();
        if (request == null) break;
        response = performRequest(request);
        // In case they forget to set this.
        response.exitCode ??= EXIT_CODE_OK;
      } catch (e, s) {
        response = new WorkResponse()
          ..exitCode = EXIT_CODE_ERROR
          ..output = '$e\n$s';
      }

      connection.writeResponse(response);
    }
  }
}

/// Default implementation of [SyncWorkerConnection] that works with [Stdin] and
/// [Stdout].
class StdSyncWorkerConnection implements SyncWorkerConnection {
  final SyncMessageGrouper _messageGrouper;
  final Stdout _stdoutStream;

  StdSyncWorkerConnection({Stdin stdinStream, Stdout stdoutStream})
      : _messageGrouper = new SyncMessageGrouper(stdinStream ?? stdin),
        _stdoutStream = stdoutStream ?? stdout;

  @override
  WorkRequest readRequest() {
    var buffer = _messageGrouper.next;
    if (buffer == null) return null;

    return new WorkRequest.fromBuffer(buffer);
  }

  @override
  void writeResponse(WorkResponse response) {
    _stdoutStream.add(protoToDelimitedBuffer(response));
  }
}
