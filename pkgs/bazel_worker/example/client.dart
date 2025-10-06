// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:bazel_worker/driver.dart';

void main() async {
  var scratchSpace = await Directory.systemTemp.createTemp();
  var driver = BazelWorkerDriver(
    () => Process.start(Platform.resolvedExecutable, [
      Platform.script.resolve('worker.dart').toFilePath(),
    ], workingDirectory: scratchSpace.path),
    maxWorkers: 4,
  );
  var response = await driver.doWork(WorkRequest(arguments: ['foo']));
  if (response.exitCode != EXIT_CODE_OK) {
    print('Worker request failed');
  } else {
    print('Worker request succeeded, file content:');
    var outputFile = File.fromUri(scratchSpace.uri.resolve('hello.txt'));
    print(await outputFile.readAsString());
  }
  await scratchSpace.delete(recursive: true);
  await driver.terminateWorkers();
}
