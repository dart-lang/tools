// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8, LineSplitter;
import 'dart:io';

import 'collect.dart';
import 'util.dart';

Future<Map<String, dynamic>> runAndCollect(String scriptPath,
    {List<String> scriptArgs,
    bool checked = false,
    String packageRoot,
    bool includeDart = false,
    Duration timeout}) async {
  final dartArgs = [
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

  final process = await Process.start('dart', dartArgs);
  final serviceUriCompleter = Completer<Uri>();
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    final uri = extractObservatoryUri(line);
    if (uri != null) {
      serviceUriCompleter.complete(uri);
    }
  });

  final serviceUri = await serviceUriCompleter.future;
  Map<String, dynamic> coverage;
  try {
    coverage = await collect(serviceUri, true, true, includeDart, <String>{},
        timeout: timeout);
  } finally {
    await process.stderr.drain<List<int>>();
  }
  final exitStatus = await process.exitCode;
  if (exitStatus != 0) {
    throw 'Process exited with exit code $exitStatus';
  }
  return coverage;
}
