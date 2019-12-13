// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:bazel_worker/bazel_worker.dart';

/// Example worker that just returns in its response all the arguments passed
/// separated by newlines.
class ExampleSyncWorker extends SyncWorkerLoop {
  @override
  WorkResponse performRequest(WorkRequest request) {
    return WorkResponse()
      ..exitCode = 0
      ..output = request.arguments.join('\n');
  }
}
