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

      expect(actualOutput.trimRight(), equals(expectedOutput.trimRight()));
    },
  );

  test('exits with code 64 on invalid arguments', () async {
    final packageDir = p.current;
    final result = await Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      p.join(packageDir, 'bin', 'api_summary.dart'),
      '--invalid-option',
    ], workingDirectory: packageDir);

    expect(result.exitCode, equals(64));
    expect(result.stderr, contains('Usage: api_summary'));
  });

  test('exits with code 64 on invalid pubspec.yaml', () async {
    final tempDir = await Directory.systemTemp.createTemp('api_summary_test');
    try {
      final pubspec = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('not_a_map');

      final packageDir = p.current;
      final result = await Process.run(Platform.resolvedExecutable, [
        if (Platform.packageConfig != null)
          '--packages=${Platform.packageConfig}',
        p.join(packageDir, 'bin', 'api_summary.dart'),
        '-p',
        tempDir.path,
      ], workingDirectory: packageDir);

      expect(result.exitCode, equals(64));
      expect(result.stderr, contains('Expected pubspec.yaml'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'exits with code 64 when no analysis context is found (missing lib/)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('api_summary_test');
      ProcessResult? result;
      try {
        final pubspec = File(p.join(tempDir.path, 'pubspec.yaml'));
        await pubspec.writeAsString('name: foo\n');

        final packageDir = p.current;
        result = await Process.run(Platform.resolvedExecutable, [
          if (Platform.packageConfig != null)
            '--packages=${Platform.packageConfig}',
          p.join(packageDir, 'bin', 'api_summary.dart'),
          '-p',
          tempDir.path,
        ], workingDirectory: packageDir);

        expect(result.exitCode, equals(64));
        expect(result.stderr, contains('No "lib" directory found'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
