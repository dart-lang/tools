// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../async_message_grouper.dart';
import '../worker_protocol.pb.dart';
import '../constants.dart';
import '../utils.dart';

/// A connection from a `BazelWorkerDriver` to a worker.
///
/// Unlike `WorkerConnection` there is no synchronous version of this class.
/// This is because drivers talk to multiple workers, so they should never block
/// when waiting for the response of any individual worker.
abstract class DriverConnection {
  Future<WorkResponse> readResponse();

  void writeRequest(WorkRequest request);

  Future cancel();
}

/// Default implementation of [DriverConnection] that works with [Stdin]
/// and [Stdout].
class StdDriverConnection implements DriverConnection {
  final AsyncMessageGrouper _messageGrouper;
  final StreamSink<List<int>> _outputStream;

  StdDriverConnection(
      {Stream<List<int>> inputStream, StreamSink<List<int>> outputStream})
      : _messageGrouper = new AsyncMessageGrouper(inputStream ?? stdin),
        _outputStream = outputStream ?? stdout;

  factory StdDriverConnection.forWorker(Process worker) =>
      new StdDriverConnection(
          inputStream: worker.stdout, outputStream: worker.stdin);

  /// Note: This will attempts to recover from invalid proto messages by parsing
  /// them as strings. This is a common error case for workers (they print a
  /// message to stdout on accident). This isn't perfect however as it only
  /// happens if the parsing throws, you can still hang indefinitely if the
  /// [MessageGrouper] doesn't find what it thinks is the end of a proto
  /// message.
  @override
  Future<WorkResponse> readResponse() async {
    var buffer = await _messageGrouper.next;
    if (buffer == null) return null;

    WorkResponse response;
    try {
      response = new WorkResponse.fromBuffer(buffer);
    } catch (_) {
      try {
        // Try parsing the message as a string and set that as the output.
        var output = UTF8.decode(buffer);
        var response = new WorkResponse()
          ..exitCode = EXIT_CODE_ERROR
          ..output = 'Worker sent an invalid response:\n$output';
        return response;
      } catch (_) {
        // Fall back to original exception and rethrow if we fail to parse as
        // a string.
      }
      rethrow;
    }
    return response;
  }

  @override
  void writeRequest(WorkRequest request) {
    _outputStream.add(protoToDelimitedBuffer(request));
  }

  @override
  Future cancel() => _messageGrouper.cancel();
}
