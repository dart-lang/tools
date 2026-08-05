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
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  late String jsonSummary;
  late String textSummary;
  late String yamlSummary;

  setUpAll(() async {
    final apiPackage = await apiSummary(_pkgDir());

    jsonSummary =
        '${const JsonEncoder.withIndent('  ').convert(apiPackage.toJson())}\n';
    textSummary = apiPackage.toString();
    final editor = YamlEditor('');
    editor.update([], apiPackage.toJson());
    yamlSummary = '$editor\n';
  });

  test('json output matches api.json', () {
    _verifyGolden(jsonSummary, 'api.json');
  });

  test('text output matches api.txt', () {
    _verifyGolden(textSummary, 'api.txt');
  });

  test('yaml output matches api.yaml', () {
    _verifyGolden(yamlSummary, 'api.yaml');
  });

  test('rehydrated json renders identical text summary', () {
    final parsed = jsonDecode(jsonSummary) as Map<String, dynamic>;
    final apiPackage = ApiSummary.fromJson(parsed);
    final renderedText = apiPackage.toString();

    expect(renderedText, equals(textSummary));
  });

  test('throws ArgumentError on missing pubspec.yaml', () async {
    await expectLater(
      apiSummary('/non_existent_directory_12345'),
      throwsArgumentError,
    );
  });

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

void _verifyGolden(String actual, String goldenFileName) {
  final goldenFile = File(p.join(_pkgDir(), goldenFileName));
  final expectedText = LineSplitter.split(
    goldenFile.readAsStringSync(),
  ).join('\n');
  final actualText = LineSplitter.split(actual).join('\n');

  expect(actualText, equals(expectedText));
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
