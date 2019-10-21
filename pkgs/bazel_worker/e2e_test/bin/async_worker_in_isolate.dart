// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:e2e_test/forwards_to_isolate_async_worker.dart';

/// Wraps the worker provided by `async_worker.dart`, launching it in an
/// isolate. Requests are forwarded to the isolate and responses are returned
/// directly from the isolate.
///
/// Anyone actually using the facility to wrap a worker in an isolate will want
/// to use this code to do additional work, for example post processing one of
/// the output files.
Future main(List<String> args, SendPort message) async {
  var receivePort = ReceivePort();
  await Isolate.spawnUri(
      Uri.file('async_worker.dart'), [], receivePort.sendPort);

  var worker = await ForwardsToIsolateAsyncWorker.create(receivePort);
  await worker.run();
}
