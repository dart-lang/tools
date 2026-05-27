// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'api_summary output matches api.txt',
    timeout: const Timeout.factor(3),
    () async {
      final packageDir = p.current;

      final result = await Process.run(Platform.resolvedExecutable, [
        if (Platform.packageConfig != null)
          '--packages=${Platform.packageConfig}',
        p.join(packageDir, 'bin', 'api_summary.dart'),
        '-p',
        packageDir,
      ], workingDirectory: packageDir);

      expect(
        result.exitCode,
        equals(0),
        reason: 'CLI run failed with stderr:\n${result.stderr}',
      );

      final goldenFile = File(p.join(packageDir, 'api.txt'));
      final expectedOutput = LineSplitter.split(
        goldenFile.readAsStringSync(),
      ).join('\n');
      final actualOutput = LineSplitter.split(
        result.stdout.toString(),
      ).join('\n');

      expect(actualOutput, equals(expectedOutput));
    },
  );
}
