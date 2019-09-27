// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

// explicitly using a package import to validate hitmap coverage of packages
import 'package:coverage/src/util.dart';

import 'test_app_isolate.dart';

Future<Null> main() async {
  for (var i = 0; i < 10; i++) {
    for (var j = 0; j < 10; j++) {
      final sum = usedMethod(i, j);
      if (sum != (i + j)) {
        throw 'bad method!';
      }
    }
  }

  final ReceivePort port = ReceivePort();

  final Isolate isolate =
      await Isolate.spawn(isolateTask, [port.sendPort, 1, 2], paused: true);
  await Service.controlWebServer(enable: true);
  final isolateID = Service.getIsolateID(isolate);
  print('isolateId = $isolateID');

  isolate.addOnExitListener(port.sendPort);
  isolate.resume(isolate.pauseCapability);

  final int value = await port.first;
  if (value != 3) {
    throw 'expected 3!';
  }

  final int result = await retry(() async => 42, const Duration(seconds: 1));
  print(result);
}

int usedMethod(int a, int b) {
  return a + b;
}

int unusedMethod(int a, int b) {
  return a - b;
}
