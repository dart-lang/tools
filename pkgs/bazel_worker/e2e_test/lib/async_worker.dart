// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:bazel_worker/bazel_worker.dart';

/// Example worker that just returns in its response all the arguments passed
/// separated by newlines.
class ExampleAsyncWorker extends AsyncWorkerLoop {
  Future<WorkResponse> performRequest(WorkRequest request) async {
    return new WorkResponse()
      ..exitCode = 0
      ..output = request.arguments.join('\n');
  }
}
