// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:process/process.dart';

Future<void> main() async {
  const processManager = LocalProcessManager();

  final executable = Platform.resolvedExecutable;
  if (!processManager.canRun(executable)) {
    stderr.writeln('Unable to run: $executable');
    exitCode = 1;
    return;
  }

  final result = await processManager.run([executable, '--version']);
  stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.writeln('Command failed with exit code ${result.exitCode}.');
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  }
}
