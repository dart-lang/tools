// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate';

import 'package:bazel_worker/src/constants.dart';
import 'package:bazel_worker/src/driver/driver_connection.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateDriverConnection', () {
    test('handles closed port', () async {
      var isolatePort = ReceivePort();
      var outsidePort = ReceivePort();
      isolatePort.sendPort.send(outsidePort.sendPort);
      var connection = await IsolateDriverConnection.create(isolatePort);

      isolatePort.close();

      expect((await connection.readResponse()).exitCode, EXIT_CODE_BROKEN_PIPE);
    });
  });
}
