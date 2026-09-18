// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout.factor(3)
library;

import 'dart:convert';
import 'dart:io';
import 'package:api_summary/api_summary.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  late Directory tempKernelDir;
  late String compiledCliDill;

  setUpAll(() async {
    final packageDir = _pkgDir();
    Directory.current = packageDir;
    tempKernelDir = Directory.systemTemp.createTempSync(
      'api_summary_cli_test_',
    );
    compiledCliDill = p.join(tempKernelDir.path, 'api_summary.dill');
    final compileRes = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      if (Platform.packageConfig != null)
        '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
      p.join(packageDir, 'bin', 'api_summary.dart'),
      '-o',
      compiledCliDill,
    ], workingDirectory: packageDir);
    if (compileRes.exitCode != 0) {
      throw StateError(
        'Failed to compile bin/api_summary.dart to kernel:\n'
        '${compileRes.stderr}',
      );
    }
  });

  tearDownAll(() {
    if (tempKernelDir.existsSync()) {
      tempKernelDir.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runCli(List<String> args) {
    final packageDir = _pkgDir();
    return Process.run(Platform.resolvedExecutable, [
      if (Platform.packageConfig != null)
        '--packages=${Platform.packageConfig}',
      compiledCliDill,
      ...args,
    ], workingDirectory: packageDir);
  }

  test('text output matches api.txt', expectApiSummaryClean);

  test(
    'json output matches api.json',
    () => expectApiSummaryClean(format: ApiSummaryFormat.json),
  );

  test(
    'yaml output matches api.yaml',
    () => expectApiSummaryClean(format: ApiSummaryFormat.yaml),
  );

  test('rehydrated json renders identical text summary', () async {
    final apiPackage = await apiSummary(_pkgDir());
    final jsonSummary = ApiSummaryFormat.json.format(apiPackage);
    final textSummary = ApiSummaryFormat.text.format(apiPackage);
    final parsed = jsonDecode(jsonSummary) as Map<String, dynamic>;
    final rehydrated = ApiSummary.fromJson(parsed);

    expect(rehydrated.toString(), equals(textSummary));
  });

  test('expectApiSummaryClean throws when golden file is missing', () async {
    final samplePkgDir = await _createSandboxPackage();
    final missingPath = p.join(samplePkgDir, 'missing_api.txt');
    await expectLater(
      expectApiSummaryClean(
        packagePath: samplePkgDir,
        goldenFilePath: missingPath,
      ),
      throwsA(
        isA<ApiSummaryVerificationException>()
            .having((e) => e.goldenFilePath, 'goldenFilePath', missingPath)
            .having((e) => e.expected, 'expected', isNull)
            .having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains('does not exist'),
                contains('dart run api_summary --output=missing_api.txt'),
              ),
            ),
      ),
    );
  });

  test('expectApiSummaryClean throws with diff on mismatch', () async {
    final samplePkgDir = await _createSandboxPackage();
    File(
      p.join(samplePkgDir, 'api.txt'),
    ).writeAsStringSync('environment:\n  stale_line\n');

    await expectLater(
      expectApiSummaryClean(packagePath: samplePkgDir),
      throwsA(
        isA<ApiSummaryVerificationException>()
            .having((e) => e.expected, 'expected', contains('stale_line'))
            .having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains('does not match the current public API'),
                contains('@@ line 2 @@'),
                contains('-   stale_line'),
                contains('dart run api_summary --write'),
              ),
            ),
      ),
    );
  });

  test('CLI --write and --check round-trip in sandbox package', () async {
    final samplePkgDir = await _createSandboxPackage();

    // 1. --check fails with exit code 1 before api.txt exists
    final checkMissing = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkMissing.exitCode, equals(1));
    expect(checkMissing.stderr, contains('does not exist'));
    expect(checkMissing.stderr, contains('dart run api_summary --write'));

    // 2. --write creates api.txt
    final writeRes = await runCli(['-p', samplePkgDir, '--write']);
    expect(writeRes.exitCode, equals(0), reason: '${writeRes.stderr}');
    final generatedFile = File(p.join(samplePkgDir, 'api.txt'));
    expect(generatedFile.existsSync(), isTrue);
    expect(
      generatedFile.readAsStringSync(),
      contains('add (function: int Function(int, int))'),
    );

    // 3. --check now succeeds with exit code 0
    final checkClean = await runCli(['-p', samplePkgDir, '--check']);
    expect(checkClean.exitCode, equals(0), reason: '${checkClean.stderr}');

    // 4. Relative -o with -p resolves relative to packagePath for write & check
    final writeCustom = await runCli([
      '-p',
      samplePkgDir,
      '-o',
      'custom_api.txt',
    ]);
    expect(writeCustom.exitCode, equals(0), reason: '${writeCustom.stderr}');
    expect(File(p.join(samplePkgDir, 'custom_api.txt')).existsSync(), isTrue);

    final checkCustom = await runCli([
      '-p',
      samplePkgDir,
      '-o',
      'custom_api.txt',
      '--check',
    ]);
    expect(checkCustom.exitCode, equals(0), reason: '${checkCustom.stderr}');

    // 5. --write and --check together exits with code 64
    final conflict = await runCli(['-p', samplePkgDir, '--write', '--check']);
    expect(conflict.exitCode, equals(64));
    expect(
      conflict.stderr,
      contains('Cannot specify both --write and --check.'),
    );
  });

  test('throws ArgumentError on missing pubspec.yaml', () async {
    await expectLater(
      apiSummary('/non_existent_directory_12345'),
      throwsArgumentError,
    );
  });

  test('exits with code 64 on invalid arguments', () async {
    final result = await runCli(['--invalid-option']);

    expect(result.exitCode, equals(64));
    expect(result.stderr, contains('Usage: api_summary'));
  });

  test('exits with code 64 on invalid pubspec.yaml', () async {
    await d.file('pubspec.yaml', 'not_a_map').create();

    final result = await runCli(['-p', d.sandbox]);

    expect(result.exitCode, equals(64));
    expect(result.stderr, contains('Failed to parse pubspec.yaml'));
  });

  test(
    'exits with code 64 when no analysis context is found (missing lib/)',
    () async {
      await d.file('pubspec.yaml', 'name: foo\n').create();

      final result = await runCli(['-p', d.sandbox]);

      expect(result.exitCode, equals(64));
      expect(result.stderr, contains('No "lib" directory found'));
    },
  );
}

Future<String> _createSandboxPackage() async {
  await d.dir('pkg', [
    d.file('pubspec.yaml', 'name: sample_pkg\nenvironment:\n  sdk: ^3.12.0\n'),
    d.dir('.dart_tool', [
      d.file(
        'package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'sample_pkg',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
          ],
        }),
      ),
    ]),
    d.dir('lib', [
      d.file('sample_pkg.dart', 'int add(int a, int b) => a + b;\n'),
    ]),
  ]).create();
  return p.join(d.sandbox, 'pkg');
}

// Dynamically locate the api_summary package root
String _pkgDir() {
  var packageDir = p.normalize(p.absolute(Directory.current.path));
  if (!_isApiSummaryDir(packageDir)) {
    for (final dir in ['pkgs', 'pkg']) {
      final candidate = p.join(packageDir, dir, 'api_summary');
      if (_isApiSummaryDir(candidate)) {
        packageDir = candidate;
        break;
      }
    }
  }

  return packageDir;
}

bool _isApiSummaryDir(String dir) {
  final pubspec = File(p.join(dir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  return pubspec.readAsStringSync().contains('name: api_summary');
}
