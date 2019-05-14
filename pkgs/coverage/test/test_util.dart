// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

final String testAppPath = p.join('test', 'test_files', 'test_app.dart');

const Duration timeout = Duration(seconds: 20);

Future<Process> runTestApp(int openPort) async {
  return Process.start('dart', [
    '--enable-vm-service=$openPort',
    '--pause_isolates_on_exit',
    testAppPath
  ]);
}
