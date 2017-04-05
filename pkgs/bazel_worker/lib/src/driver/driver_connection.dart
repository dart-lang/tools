// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../async_message_grouper.dart';
import '../worker_protocol.pb.dart';
import '../utils.dart';

/// Interface for a [DriverConnection].
abstract class DriverConnection {
  /// Reads a [WorkResponse] asynchronously.
  Future<WorkResponse> readResponse();

  /// Writes a [WorkRequest].
  void writeRequest(WorkRequest request);
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

  @override
  Future<WorkResponse> readResponse() async {
    var buffer = await _messageGrouper.next;
    if (buffer == null) return null;

    return new WorkResponse.fromBuffer(buffer);
  }

  @override
  void writeRequest(WorkRequest request) {
    _outputStream.add(protoToDelimitedBuffer(request));
  }
}
