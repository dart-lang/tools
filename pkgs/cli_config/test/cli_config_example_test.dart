// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('resolve command line paths relative to working directory', () async {
    await inTempDir((tempUri) async {
      final rootUri = Directory.current.uri.normalizePath();
      final examplePackageUri =
          rootUri.resolve('example${Platform.pathSeparator}');
      final entryPoint = 'bin${Platform.pathSeparator}cli_config_example.dart';
      const pubSpec = 'pubspec.yaml';
      for (final filename in [entryPoint, pubSpec]) {
        final targetUri = tempUri.resolve(filename);
        await File.fromUri(targetUri).create(recursive: true);
        await File.fromUri(examplePackageUri.resolve(filename))
            .copy(targetUri.toFilePath());
      }
      final pubspecFile = File.fromUri(tempUri.resolve(pubSpec));
      await pubspecFile.writeAsString(
        (await pubspecFile.readAsString())
            .replaceAll('path: ../', 'path: ${rootUri.toFilePath()}'),
      );

      final pubGetResult = await runProcess(
        executable: Uri.file(Platform.resolvedExecutable),
        arguments: ['pub', 'get'],
        workingDirectory: tempUri,
      );
      expect(pubGetResult.exitCode, 0);

      {
        final commandLinePath = Uri.file(
            'a${Platform.pathSeparator}b${Platform.pathSeparator}d.ext');
        final result = await runProcess(
          executable: Uri.file(Platform.resolvedExecutable),
          arguments: [
            tempUri.resolve(entryPoint).toFilePath(),
            '-Dmy_path=${commandLinePath.toFilePath()}'
          ],
          workingDirectory: rootUri,
        );
        final stdout = (result.stdout as String).trim();
        final resolvedPath = Uri.file(stdout);
        expect(resolvedPath, rootUri.resolveUri(commandLinePath));
      }

      {
        final commandLinePath = Uri.file(
            'a${Platform.pathSeparator}b${Platform.pathSeparator}d.ext');
        final result = await runProcess(
          executable: Uri.file(Platform.resolvedExecutable),
          arguments: [
            tempUri.resolve(entryPoint).toFilePath(),
            '-Dmy_path=${commandLinePath.toFilePath()}'
          ],
          workingDirectory: tempUri,
        );
        final stdout = (result.stdout as String).trim();
        final resolvedPath = Uri.file(stdout);
        expect(resolvedPath, tempUri.resolveUri(commandLinePath));
      }

      final pathInFile =
          Uri.file('a${Platform.pathSeparator}b${Platform.pathSeparator}d.ext');
      final configUri = tempUri.resolve('config.yaml');
      await File.fromUri(configUri).writeAsString('''
my_path: ${pathInFile.toFilePath()}
''');

      {
        final result = await runProcess(
          executable: Uri.file(Platform.resolvedExecutable),
          arguments: [
            tempUri.resolve(entryPoint).toFilePath(),
            '--config=${configUri.toFilePath()}'
          ],
          workingDirectory: tempUri,
        );
        final stdout = (result.stdout as String).trim();
        final resolvedPath = Uri.file(stdout);
        expect(resolvedPath, tempUri.resolveUri(pathInFile));
      }

      {
        final result = await runProcess(
          executable: Uri.file(Platform.resolvedExecutable),
          arguments: [
            tempUri.resolve(entryPoint).toFilePath(),
            '--config=${configUri.toFilePath()}'
          ],
          workingDirectory: rootUri,
        );
        final stdout = (result.stdout as String).trim();
        final resolvedPath = Uri.file(stdout);
        expect(resolvedPath, tempUri.resolveUri(pathInFile));
      }
    });
  });
}
