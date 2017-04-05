// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../worker_protocol.pb.dart';

/// Interface for a [WorkerConnection].
///
/// Use [SyncWorkerConnection] or [AsyncWorkerConnection] implementations.
abstract class WorkerConnection {
  /// Read a [WorkRequest]. Returns either [Future<WorkRequest>] or
  /// [WorkRequest].
  FutureOr<WorkRequest> readRequest();

  /// Writes a [WorkResponse].
  void writeResponse(WorkResponse response);
}
