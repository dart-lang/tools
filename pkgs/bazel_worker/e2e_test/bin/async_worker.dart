// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:e2e_test/async_worker.dart';

Future main() async {
  await new ExampleAsyncWorker().run();
}
