// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import '../api_summary.dart';

/// Supported serialization formats for [ApiSummary].
enum ApiSummaryFormat {
  /// Human-readable text summary (`api.txt`).
  text('api.txt'),

  /// Pretty-printed JSON summary (`api.json`).
  json('api.json'),

  /// YAML summary (`api.yaml`).
  yaml('api.yaml');

  const ApiSummaryFormat(this.defaultFileName);

  /// The default golden file name for this format in a package root.
  final String defaultFileName;

  /// Formats [summary] according to this format.
  String format(ApiSummary summary) => switch (this) {
    ApiSummaryFormat.text => summary.toString(),
    ApiSummaryFormat.json =>
      '${const JsonEncoder.withIndent('  ').convert(summary.toJson())}\n',
    ApiSummaryFormat.yaml => () {
      final editor = YamlEditor('');
      editor.update([], summary.toJson());
      return '$editor\n';
    }(),
  };
}

/// Exception thrown by [expectApiSummaryClean] when a package's golden API
/// summary file is missing or out of sync with the package's public API.
final class ApiSummaryVerificationException implements Exception {
  /// A human-readable description of the verification failure, including a
  /// line diff and remediation command.
  final String message;

  /// The path to the golden file that was checked.
  final String goldenFilePath;

  /// The expected content read from [goldenFilePath], or `null` if the file
  /// did not exist.
  final String? expected;

  /// The actual summary generated from the package's current source code.
  final String actual;

  ApiSummaryVerificationException({
    required this.message,
    required this.goldenFilePath,
    required this.actual,
    this.expected,
  });

  @override
  String toString() => 'ApiSummaryVerificationException: $message';
}

/// Verifies that the package's generated [ApiSummary] matches the golden file
/// at [goldenFilePath] (defaults to [ApiSummaryFormat.defaultFileName] inside
/// [packagePath]).
///
/// If [packagePath] is omitted, defaults to [Directory.current].
///
/// Throws an [ApiSummaryVerificationException] if the golden file does not
/// exist or if its contents differ from the generated summary.
///
/// Because all parameters are optional and named, [expectApiSummaryClean] can
/// be passed directly as a tear-off to `test()`:
/// ```dart
/// import 'package:api_summary/api_summary.dart';
/// import 'package:test/scaffolding.dart';
///
/// void main() {
///   test('api_summary', expectApiSummaryClean);
/// }
/// ```
Future<void> expectApiSummaryClean({
  String? goldenFilePath,
  String? packagePath,
  String? packageName,
  ApiSummaryCustomizer? customizer,
  ApiSummaryFormat format = ApiSummaryFormat.text,
}) async {
  final resolvedPackagePath = p.normalize(
    p.absolute(packagePath ?? Directory.current.path),
  );

  final effectiveGoldenPath = goldenFilePath == null
      ? p.join(resolvedPackagePath, format.defaultFileName)
      : (p.isAbsolute(goldenFilePath)
            ? p.normalize(goldenFilePath)
            : p.normalize(p.join(resolvedPackagePath, goldenFilePath)));

  final summary = await apiSummary(
    resolvedPackagePath,
    packageName: packageName,
    customizer: customizer,
  );
  final actualOutput = format.format(summary);
  final goldenFile = File(effectiveGoldenPath);

  final displayGoldenPath = p.isWithin(resolvedPackagePath, effectiveGoldenPath)
      ? p.relative(effectiveGoldenPath, from: resolvedPackagePath)
      : effectiveGoldenPath;
  final remediationCommand = _buildRemediationCommand(
    format: format,
    displayGoldenPath: displayGoldenPath,
  );

  if (!goldenFile.existsSync()) {
    throw ApiSummaryVerificationException(
      message:
          'Golden file "$displayGoldenPath" does not exist at '
          '"$effectiveGoldenPath".\n'
          'To generate it, run:\n'
          '  $remediationCommand',
      goldenFilePath: effectiveGoldenPath,
      actual: actualOutput,
    );
  }

  final expectedRaw = goldenFile.readAsStringSync();
  final expectedLines = LineSplitter.split(expectedRaw).toList();
  final actualLines = LineSplitter.split(actualOutput).toList();

  if (!_linesEqual(expectedLines, actualLines)) {
    final diff = _buildLineDiff(expectedLines, actualLines);
    throw ApiSummaryVerificationException(
      message:
          '"$displayGoldenPath" does not match the current public API of '
          'package "${summary.name}".\n\n'
          '$diff\n\n'
          'To update the golden file, run:\n'
          '  $remediationCommand',
      goldenFilePath: effectiveGoldenPath,
      expected: expectedRaw,
      actual: actualOutput,
    );
  }
}

String _buildRemediationCommand({
  required ApiSummaryFormat format,
  required String displayGoldenPath,
}) {
  final args = <String>['dart run api_summary'];
  if (displayGoldenPath == format.defaultFileName) {
    args.add('--write');
    if (format != ApiSummaryFormat.text) {
      args.add('--format=${format.name}');
    }
  } else {
    if (format != ApiSummaryFormat.text) {
      args.add('--format=${format.name}');
    }
    args.add('--output=$displayGoldenPath');
  }
  return args.join(' ');
}

bool _linesEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _buildLineDiff(List<String> expected, List<String> actual) {
  var prefix = 0;
  final minLen = expected.length < actual.length
      ? expected.length
      : actual.length;
  while (prefix < minLen && expected[prefix] == actual[prefix]) {
    prefix++;
  }

  var expectedSuffix = expected.length;
  var actualSuffix = actual.length;
  while (expectedSuffix > prefix &&
      actualSuffix > prefix &&
      expected[expectedSuffix - 1] == actual[actualSuffix - 1]) {
    expectedSuffix--;
    actualSuffix--;
  }

  final buffer = StringBuffer();
  buffer.writeln('@@ line ${prefix + 1} @@');

  const maxLinesShown = 20;
  final removedCount = expectedSuffix - prefix;
  for (var i = 0; i < removedCount && i < maxLinesShown; i++) {
    buffer.writeln('- ${expected[prefix + i]}');
  }
  if (removedCount > maxLinesShown) {
    buffer.writeln('... (${removedCount - maxLinesShown} more removed lines)');
  }

  final addedCount = actualSuffix - prefix;
  for (var i = 0; i < addedCount && i < maxLinesShown; i++) {
    buffer.writeln('+ ${actual[prefix + i]}');
  }
  if (addedCount > maxLinesShown) {
    buffer.writeln('... (${addedCount - maxLinesShown} more added lines)');
  }

  return buffer.toString().trimRight();
}
