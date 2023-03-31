// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

const keepTempKey = 'KEEP_TEMPORARY_DIRECTORIES';

Future<void> inTempDir(
  Future<void> Function(Uri tempUri) fun, {
  String? prefix,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  // Deal with Windows temp folder aliases.
  final tempUri =
      Directory(await tempDir.resolveSymbolicLinks()).uri.normalizePath();
  try {
    await fun(tempUri);
  } finally {
    if (!Platform.environment.containsKey(keepTempKey) ||
        Platform.environment[keepTempKey]!.isEmpty) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<ProcessResult> runProcess({
  required Uri executable,
  List<String> arguments = const [],
  required Uri workingDirectory,
}) async {
  final result = await Process.run(
    executable.toFilePath(),
    arguments,
    workingDirectory: workingDirectory.toFilePath(),
  );
  if (result.exitCode != 0) {
    print(result.stdout);
    print(result.stderr);
    print(result.exitCode);
  }
  return result;
}
