// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.util;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final testAppPath = p.join('test', 'test_files', 'test_app.dart');

const timeout = const Duration(seconds: 10);

Future runTestApp(int openPort) async {
  var proc = await Process.start('dart', [
    '--enable-vm-service=$openPort',
    '--pause_isolates_on_exit',
    testAppPath
  ]);

  return Future.wait([
    _transformStd(proc.stdout),
    _transformStd(proc.stderr),
    proc.exitCode
  ]).timeout(timeout, onTimeout: () {
    throw 'We timed out waiting for the sample app to finish.';
  });
}

Future _transformStd(Stream<List<int>> source) {
  return source
      .transform(SYSTEM_ENCODING.decoder)
      .transform(const LineSplitter())
      .forEach((line) {
    // Uncomment to debug output from `testApp`
    // print(line);
  });
}
