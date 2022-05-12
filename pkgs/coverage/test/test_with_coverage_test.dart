// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
  setUpAll(() {
    final localPub = _runSync(['pub', 'get']);
    assert(_wasSuccessful(localPub));

    final globalPub =
        _runSync(['pub', 'global', 'activate', '-s', 'git', _pkgDir]);
    assert(_wasSuccessful(globalPub));
  });

  tearDownAll(() {
    for (final entry in [
      Directory(_pubCachePathInTestPkgSubDir),
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

  test('dart run bin/test_with_coverage.dart', () {
    return _runTest(['run', _testWithCoveragePath]).then(_expectSuccessful);
  });
  test('dart run coverage:test_with_coverage', () {
    return _runTest(['run', 'coverage:test_with_coverage'])
        .then(_expectSuccessful);
  });
  test('dart pub global run coverage:test_with_coverage', () {
    return _runTest(['pub', 'global', 'run', 'coverage:test_with_coverage'])
        .then(_expectSuccessful);
  });
}

ProcessResult _runSync(List<String> args) =>
    Process.runSync(Platform.executable, args,
        workingDirectory: _testPkgDirPath, environment: _env);

Future<ProcessResult> _run(List<String> args) =>
    Process.run(Platform.executable, args,
        workingDirectory: _testPkgDirPath, environment: _env);

bool _wasSuccessful(ProcessResult result) => result.exitCode == 0;

void _expectSuccessful(ProcessResult result) {
  if (!_wasSuccessful(result)) {
    fail(
      "Process excited with exit code: ${result.exitCode}. Stderr: ${result.stderr}",
    );
  }
}

Future<ProcessResult> _runTest(List<String> invokeArgs) =>
    _run([...invokeArgs, '--port', '${_port++}', '--test', _testPkgExePath]);
