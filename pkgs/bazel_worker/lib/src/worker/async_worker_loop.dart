// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../constants.dart';
import '../async_message_grouper.dart';
import '../utils.dart';
import '../worker_protocol.pb.dart';
import 'worker_connection.dart';
import 'worker_loop.dart';

/// Connection between a worker and input / output.
abstract class AsyncWorkerConnection implements WorkerConnection {
  /// Read a new [WorkRequest]. Returns [null] when there are no more requests.
  Future<WorkRequest> readRequest();

  /// Write the given [response] as bytes to the output.
  void writeResponse(WorkResponse response);
}

/// Persistent Bazel worker loop.
///
/// Extend this class and implement the `performRequest` method.
abstract class AsyncWorkerLoop implements WorkerLoop {
  final AsyncWorkerConnection connection;

  AsyncWorkerLoop({AsyncWorkerConnection connection})
      : this.connection = connection ?? new StdAsyncWorkerConnection();

  /// Perform a single [WorkRequest], and return a [WorkResponse].
  Future<WorkResponse> performRequest(WorkRequest request);

  /// Run the worker loop. The returned [Future] doesn't complete until
  /// [connection#readRequest] returns `null`.
  Future run() async {
    while (true) {
      WorkResponse response;
      try {
        var request = await connection.readRequest();
        if (request == null) break;
        var printMessages = new StringBuffer();
        response = await runZoned(() => performRequest(request),
            zoneSpecification:
                new ZoneSpecification(print: (self, parent, zone, message) {
          printMessages.writeln();
          printMessages.write(message);
        }));
        if (printMessages.isNotEmpty) {
          response.output = '${response.output}$printMessages';
        }
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

/// Default implementation of [AsyncWorkerConnection] that works with [Stdin]
/// and [Stdout].
class StdAsyncWorkerConnection implements AsyncWorkerConnection {
  final AsyncMessageGrouper _messageGrouper;
  final StreamSink<List<int>> _outputStream;

  StdAsyncWorkerConnection(
      {Stream<List<int>> inputStream, StreamSink<List<int>> outputStream})
      : _messageGrouper = new AsyncMessageGrouper(inputStream ?? stdin),
        _outputStream = outputStream ?? stdout;

  @override
  Future<WorkRequest> readRequest() async {
    var buffer = await _messageGrouper.next;
    if (buffer == null) return null;

    return new WorkRequest.fromBuffer(buffer);
  }

  @override
  void writeResponse(WorkResponse response) {
    _outputStream.add(protoToDelimitedBuffer(response));
  }
}
