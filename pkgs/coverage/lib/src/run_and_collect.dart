// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.run_and_collect;

import 'dart:async';
import 'dart:convert' show UTF8, LineSplitter;
import 'dart:io';

import 'collect.dart';
import 'util.dart';

Future<Map<String, dynamic>> runAndCollect(String scriptPath,
    {List<String> scriptArgs,
    bool checked: true,
    String packageRoot,
    Duration timeout}) async {
  var dartArgs = [
    '--enable-vm-service',
    '--pause_isolates_on_exit',
  ];

  if (checked) {
    dartArgs.add('--checked');
  }

  if (packageRoot != null) {
    dartArgs.add('--package-root=$packageRoot');
  }

  dartArgs.add(scriptPath);

  if (scriptArgs != null) {
    dartArgs.addAll(scriptArgs);
  }

  var process = await Process.start('dart', dartArgs);
  var serviceUriCompleter = new Completer<Uri>();
  process.stdout
      .transform(UTF8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    var uri = extractObservatoryUri(line);
    if (uri != null) {
      serviceUriCompleter.complete(uri);
    }
  });

  var serviceUri = await serviceUriCompleter.future;
  Map<String, dynamic> coverage;
  try {
    coverage = await collect(serviceUri, true, true, timeout: timeout);
  } finally {
    await process.stderr.drain<List<int>>();
  }
  int exitStatus = await process.exitCode;
  if (exitStatus != 0) {
    throw "Process exited with exit code $exitStatus";
  }
  return coverage;
}
