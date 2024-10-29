// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:bazel_worker/driver.dart';

/// Example worker that just forwards requests to an isolate.
class ForwardsToIsolateAsyncWorker extends AsyncWorkerLoop {
  final IsolateDriverConnection _isolateDriverConnection;

  static Future<ForwardsToIsolateAsyncWorker> create(
      ReceivePort receivePort) async {
    return ForwardsToIsolateAsyncWorker(
        await IsolateDriverConnection.create(receivePort));
  }

  ForwardsToIsolateAsyncWorker(this._isolateDriverConnection);

  @override
  Future<WorkResponse> performRequest(WorkRequest request) {
    _isolateDriverConnection.writeRequest(request);
    return _isolateDriverConnection.readResponse();
  }
}
