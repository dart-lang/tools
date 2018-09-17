// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:bazel_worker/bazel_worker.dart';

/// Example worker that just forwards requests to an isolate.
class ForwardsToIsolateAsyncWorker extends AsyncWorkerLoop {
  final StreamIterator _receivePortIterator;
  final SendPort _sendPort;

  static Future<ForwardsToIsolateAsyncWorker> create(
      ReceivePort receivePort) async {
    // The first thing the isolate sends is a `SendPort` so we can communicate
    // with it.
    var receivePortIterator = new StreamIterator(receivePort);
    await receivePortIterator.moveNext();
    var sendPort = receivePortIterator.current as SendPort;
    return new ForwardsToIsolateAsyncWorker(receivePortIterator, sendPort);
  }

  ForwardsToIsolateAsyncWorker(this._receivePortIterator, this._sendPort);

  Future<WorkResponse> performRequest(WorkRequest request) async {
    // Send the request to the isolate, return the response from the isolate.
    _sendPort.send(request.writeToBuffer());
    await _receivePortIterator.moveNext();
    return WorkResponse.fromBuffer(_receivePortIterator.current as List<int>);
  }
}
