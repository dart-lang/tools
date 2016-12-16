// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.run_and_collect;

import 'dart:async';
import 'dart:io';

import 'collect.dart';
import 'util.dart';

Future<Map> runAndCollect(String scriptPath,
    {List<String> scriptArgs, String packageRoot, Duration timeout}) async {
  var openPort = await getOpenPort();

  var dartArgs = [
    '--enable-vm-service=$openPort',
    '--pause_isolates_on_exit',
  ];

  if (packageRoot != null) {
    dartArgs.add('--package-root=$packageRoot');
  }

  dartArgs.add(scriptPath);

  if (scriptArgs != null) {
    dartArgs.addAll(scriptArgs);
  }

  var process = await Process.start('dart', dartArgs);

  try {
    return collect('127.0.0.1', openPort, true, true, timeout: timeout);
  } finally {
    await process.stdout.drain();
    await process.stderr.drain();

    var code = await process.exitCode;

    if (code < 0) {
      throw "A critical exception happened in the process: exit code $code";
    }
  }
}
