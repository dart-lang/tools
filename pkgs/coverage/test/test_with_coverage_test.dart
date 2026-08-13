// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'test_util.dart';

// this package
final _pkgDir = p.absolute('');
final _testWithCoveragePath = p.join(_pkgDir, 'bin', 'test_with_coverage.dart');

// test package
final _testPkgDirPath = p.join(_pkgDir, 'test', 'test_with_coverage_package');

/// Override PUB_CACHE
///
/// Use a subdirectory different from `test/` just in case there is a problem
/// with the clean up. If other packages are present under the `test/`
/// subdirectory their tests may accidentally get run when running `dart test`
final _pubCachePathInTestPkgSubDir = p.join(_pkgDir, 'var', 'pub-cache');
final _env = {'PUB_CACHE': _pubCachePathInTestPkgSubDir};

const _testPackageName = 'coverage_integration_test_for_test_with_coverage';

Iterable<File> _dartFiles(String dir) =>
    Directory(p.join(_testPkgDirPath, dir)).listSync().whereType<File>();

String _fixTestFile(String content) =>
    content.replaceAll("import '../lib/", "import 'package:$_testPackageName/");

void main() {
  setUpAll(() async {
    for (var dir in const ['lib', 'test']) {
      await d.dir(dir, [
        for (var dartFile in _dartFiles(dir))
          d.file(
            p.basename(dartFile.path),
            _fixTestFile(dartFile.readAsStringSync()),
          ),
      ]).create();
    }

    var pubspecContent = File(
      p.join(_testPkgDirPath, 'pubspec.yaml'),
    ).readAsStringSync();

    expect(
      pubspecContent.replaceAll('\r\n', '\n'),
      contains(r'''
dependency_overrides:
  coverage:
    path: ../../
'''),
    );

    pubspecContent = pubspecContent.replaceFirst(
      'path: ../../',
      'path: $_pkgDir',
    );

    await d.file('pubspec.yaml', pubspecContent).create();

    final localPub = await _run(['pub', 'get']);
    await localPub.shouldExit(0);
  });

  tearDownAll(() async {
    if (Platform.isWindows) {
      final sandboxDir = Directory(d.sandbox);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          if (sandboxDir.existsSync()) {
            for (final entity in sandboxDir.listSync()) {
              entity.deleteSync(recursive: true);
            }
          }
          break;
        } catch (_) {}
      }
    }
  });

  test('dart run bin/test_with_coverage.dart -f', () async {
    final list = await _runTest(['run', _testWithCoveragePath, '-f']);

    final sources = list.sources();
    final functionHits = functionInfoFromSources(sources);

    expect(functionHits['package:$_testPackageName/validate_lib.dart'], {
      'product': 1,
      'sum': 1,
      'evaluateScore': 1,
    });
  });

  test('dart run bin/test_with_coverage.dart -f -- -N sum', () async {
    final list = await _runTest(
      ['run', _testWithCoveragePath, '-f'],
      extraArgs: ['--', '-N', 'sum'],
    );

    final sources = list.sources();
    final functionHits = functionInfoFromSources(sources);

    expect(functionHits['package:$_testPackageName/validate_lib.dart'], {
      'product': 0,
      'sum': 1,
      'evaluateScore': 0,
    }, reason: 'only `sum` tests should be run');
  });

  test('dart run coverage:test_with_coverage', () async {
    await _runTest(['run', 'coverage:test_with_coverage']);
  });

  test('dart pub global run coverage:test_with_coverage', () async {
    final globalPub = await _run([
      'pub',
      'global',
      'activate',
      '-s',
      'path',
      _pkgDir,
    ]);
    await globalPub.shouldExit(0);

    await _runTest(['pub', 'global', 'run', 'coverage:test_with_coverage']);
  });

  test('dart run bin/test_with_coverage.dart --fail-under succeeds'
      'when coverage meets threshold', () async {
    // This should pass as coverage=100% when all tests run.
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '--fail-under=100',
      '--port',
      '0',
    ]);
    await process.shouldExit(0);
  });
  test('dart run bin/test_with_coverage.dart --fail-under fails'
      'when coverage is below threshold', () async {
    // This should throw an exit(1) as coverage =27.27% when only the `sum` test
    // is run i.e. out of 11 lines only 3 lines i.e. [5,7,8]will have hits>0.
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '--fail-under=90',
      '--port',
      '0',
      '--',
      '-N',
      'sum',
    ]);
    await process.shouldExit(1);
  });
  test('dart run bin/test_with_coverage.dart -b --fail-under succeeds'
      'when coverage meets threshold', () async {
    // This should pass as total lines+branches covered=20 and total lines(11)+
    // branches covered(10)=21 => percentage_covered=95.23.
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '-b',
      '--fail-under=90',
      '--port',
      '0',
    ]);
    await process.shouldExit(0);
  });
  test('dart run bin/test_with_coverage.dart -b --fail-under fails'
      'when coverage is below threshold', () async {
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '-b',
      '--fail-under=99',
      '--port',
      '0',
    ]);
    await process.shouldExit(1);
  });

  test(
    'dart run bin/test_with_coverage.dart -p chrome',
    onPlatform: const {'windows': Skip('Chrome tests skipped on Windows')},
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final list = await _runTest([
        'run',
        _testWithCoveragePath,
        '-p',
        'chrome',
      ]);
      final sources = list.sources();
      final lineHits = lineHitsFromSources(sources);

      final libHits = lineHits['package:$_testPackageName/validate_lib.dart'];
      expect(libHits, isNotNull);
      expect(libHits![6], greaterThanOrEqualTo(1));
      expect(libHits[14], greaterThanOrEqualTo(1));
      expect(libHits[22], greaterThanOrEqualTo(1));
      expect(
        lineHits.keys.where((source) => source.endsWith('_test.dart')),
        isEmpty,
        reason: 'test files are excluded without --include-test-files',
      );
    },
  );

  test(
    'dart run bin/test_with_coverage.dart -p chrome --include-test-files',
    onPlatform: const {'windows': Skip('Chrome tests skipped on Windows')},
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final list = await _runTest([
        'run',
        _testWithCoveragePath,
        '-p',
        'chrome',
        '--include-test-files',
      ]);
      final sources = list.sources();
      final lineHits = lineHitsFromSources(sources);

      expect(
        lineHits.keys.where((source) => source.endsWith('_test.dart')),
        isNotEmpty,
        reason: '--include-test-files should include test sources',
      );
    },
  );

  test('dart run bin/test_with_coverage.dart -p firefox is rejected', () async {
    final process = await _run(['run', _testWithCoveragePath, '-p', 'firefox']);
    await process.shouldExit(1);
  });

  test(
    'dart run bin/test_with_coverage.dart -f -p chrome is rejected',
    () async {
      final process = await _run([
        'run',
        _testWithCoveragePath,
        '-f',
        '-p',
        'chrome',
      ]);
      await process.shouldExit(1);
    },
  );

  // An unsupported platform must be rejected during argument parsing, before
  // any test process is started. Asserting only on the exit code is not
  // enough: `dart test -p <unsupported>` also exits 1, so a broken allowlist
  // would still look like a pass.
  test('dart run bin/test_with_coverage.dart -p firefox fails during '
      'argument parsing', () async {
    final process = await _run(['run', _testWithCoveragePath, '-p', 'firefox']);
    await expectLater(
      process.stdout,
      emitsThrough(contains('Unsupported --platform "firefox"')),
    );
    await process.shouldExit(1);
  });

  test('dart run bin/test_with_coverage.dart -f -p chrome fails during '
      'argument parsing', () async {
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '-f',
      '-p',
      'chrome',
    ]);
    await expectLater(
      process.stdout,
      emitsThrough(
        contains('--function-coverage is not supported for web platforms.'),
      ),
    );
    await process.shouldExit(1);
  });

  test('dart run bin/test_with_coverage.dart -b -p chrome fails during '
      'argument parsing', () async {
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '-b',
      '-p',
      'chrome',
    ]);
    await expectLater(
      process.stdout,
      emitsThrough(
        contains('--branch-coverage is not supported for web platforms.'),
      ),
    );
    await process.shouldExit(1);
  });

  // A platform flag after `--` would reach `dart test` and override the
  // validated platform, collecting coverage for something else entirely.
  test('dart run bin/test_with_coverage.dart rejects a platform flag passed '
      'to the test script', () async {
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '-p',
      'vm',
      '--',
      '-p',
      'chrome',
    ]);
    await expectLater(
      process.stdout,
      emitsThrough(contains('Pass the platform with --platform')),
    );
    await process.shouldExit(1);
  });

  // A test process that dies before the VM service is ready must fail fast
  // rather than waiting forever for a service URI that will never arrive.
  test('dart run bin/test_with_coverage.dart fails fast when the test process '
      'cannot start', () async {
    final process = await _run([
      'run',
      _testWithCoveragePath,
      '--test',
      p.join(d.sandbox, 'no_such_test_dir'),
    ]);
    await expectLater(
      process.stderr,
      emitsThrough(contains('exited before the VM service was ready')),
    );
    await process.shouldExit(isNot(0));
  });

  // `--platform vm` is an advertised value and must take the VM service
  // collection path, which is the only path that can produce function hits.
  test(
    'dart run bin/test_with_coverage.dart -p vm -f uses the VM flow',
    () async {
      final list = await _runTest([
        'run',
        _testWithCoveragePath,
        '-p',
        'vm',
        '-f',
      ]);

      expect(
        list.any((entry) => entry.containsKey('funcHits')),
        isTrue,
        reason:
            '--platform vm must take the VM service collection path, which '
            'is the only path that can report function coverage',
      );

      final sources = list.sources();
      final functionHits = functionInfoFromSources(sources);

      expect(functionHits['package:$_testPackageName/validate_lib.dart'], {
        'product': 1,
        'sum': 1,
        'evaluateScore': 1,
      });
    },
  );

  // The exit code of the underlying test run must reach the caller, otherwise
  // a red test suite is reported to CI as a success.
  test(
    'dart run bin/test_with_coverage.dart propagates a failing test run',
    () async {
      final process = await _run([
        'run',
        _testWithCoveragePath,
        '--port',
        '0',
        '--',
        '-N',
        'no_such_test_name_xyz',
      ]);
      await process.shouldExit(isNot(0));
    },
  );
}

Future<TestProcess> _run(List<String> args) => TestProcess.start(
  Platform.executable,
  args,
  workingDirectory: d.sandbox,
  environment: _env,
);

Future<List<Map<String, dynamic>>> _runTest(
  List<String> invokeArgs, {
  List<String>? extraArgs,
}) async {
  final process = await _run([...invokeArgs, '--port', '0', ...?extraArgs]);

  await process.shouldExit(0);

  await d.dir('coverage', [
    d.file('coverage.json', isNotEmpty),
    d.file('lcov.info', isNotEmpty),
  ]).validate();

  final coverageDataFile = File(p.join(d.sandbox, 'coverage', 'coverage.json'));

  final json = jsonDecode(coverageDataFile.readAsStringSync());

  return coverageDataFromJson(json as Map<String, dynamic>);
}
