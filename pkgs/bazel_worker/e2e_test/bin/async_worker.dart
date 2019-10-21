// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:e2e_test/async_worker.dart';

/// This worker can run in one of two ways: normally, using stdin/stdout, or
/// in an isolate, communicating over a [SendPort].
Future main(List<String> args, [SendPort sendPort]) async {
  await ExampleAsyncWorker(sendPort).run();
}
