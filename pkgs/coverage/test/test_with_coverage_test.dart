// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

// this package
final _pkgDir = p.absolute('');
final _testWithCoveragePath = p.join(_pkgDir, 'bin', 'test_with_coverage.dart');

// test package
final _testPkgDirPath = p.join(_pkgDir, 'test', 'test_with_coverage_package');
final _testPkgExePath = p.join(_testPkgDirPath, 'main.dart');

/// Override PUB_CACHE
///
/// Use a subdirectory different from `test/` just in case there is a problem
/// with the clean up. If other packages are present under the `test/`
/// subdirectory their tests may accidentally get run when running `dart test`
final _pubCachePathInTestPkgSubDir = p.join(_pkgDir, 'var', 'pub-cache');
final _env = {'PUB_CACHE': _pubCachePathInTestPkgSubDir};

int _port = 9300;

void main() {
  setUpAll(() async {
    final localPub = await _run(['pub', 'get']);
    await localPub.shouldExit(0);

    final globalPub =
        await _run(['pub', 'global', 'activate', '-s', 'path', _pkgDir]);
    await globalPub.shouldExit(0);
  });

  tearDownAll(() {
    for (final entry in [
      Directory(p.join(_testPkgDirPath, '.dart_tool')),
      Directory(p.join(_testPkgDirPath, 'coverage')),
      File(p.join(_testPkgDirPath, '.packages')),
      File(p.join(_testPkgDirPath, 'pubspec.lock')),
    ]) {
      if (entry.existsSync()) {
        entry.deleteSync(recursive: true);
      }
    }
  });

  test('dart run bin/test_with_coverage.dart', () async {
    final result = await _runTest(['run', _testWithCoveragePath]);
    await result.shouldExit(0);
  });

  test('dart run coverage:test_with_coverage', () async {
    final result = await _runTest(['run', 'coverage:test_with_coverage']);
    await result.shouldExit(0);
  });

  test('dart pub global run coverage:test_with_coverage', () async {
    final result =
        await _runTest(['pub', 'global', 'run', 'coverage:test_with_coverage']);
    await result.shouldExit(0);
  });
}

Future<TestProcess> _run(List<String> args) => TestProcess.start(
      Platform.executable,
      args,
      workingDirectory: _testPkgDirPath,
      environment: _env,
    );

Future<TestProcess> _runTest(List<String> invokeArgs) => _run([
      ...invokeArgs,
      '--port',
      '${_port++}',
      '--test',
      _testPkgExePath,
    ]);
