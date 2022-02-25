// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

final String testAppPath = p.join('test', 'test_files', 'test_app.dart');

const Duration timeout = Duration(seconds: 20);

Future<Process> runTestApp(int openPort) async {
  return Process.start(Platform.resolvedExecutable, [
    '--enable-vm-service=$openPort',
    '--pause_isolates_on_exit',
    // Dart VM versions before 2.17 don't support branch coverage.
    if (platformVersionCheck(2, 17)) '--branch-coverage',
    testAppPath
  ]);
}

final _versionPattern = RegExp('([0-9]+)\\.([0-9]+)\\.([0-9]+)');
bool platformVersionCheck(int minMajor, int minMinor) {
  final match = _versionPattern.matchAsPrefix(Platform.version);
  if (match == null) return false;
  if (match.groupCount < 3) return false;
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  return major > minMajor || (major == minMajor && minor >= minMinor);
}
