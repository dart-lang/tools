// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_catching_errors

import 'dart:io';

import 'package:api_summary/api_summary.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  try {
    final results = _parser.parse(arguments);

    if (results.flag('help')) {
      print('Usage: api_summary [options]');
      print(_parser.usage);
      return;
    }

    await _run(results);
  } on ApiSummaryVerificationException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } on FormatException catch (e) {
    _usageError(e.message);
  } on ArgumentError catch (e) {
    _usageError('${e.message}');
  }
}

void _usageError(String message) {
  stderr.writeln('Error: $message');
  stderr.writeln('\nUsage: api_summary [options]');
  stderr.writeln(_parser.usage);
  exitCode = 64;
}

Future<void> _run(ArgResults results) async {
  if (results.rest.isNotEmpty) {
    throw FormatException(
      'Unexpected positional arguments: "${results.rest.join(' ')}". '
      'Use --package-path (-p) to specify a package directory.',
    );
  }

  final packagePath = results.option('package-path') ?? Directory.current.path;
  final absolutePath = p.normalize(p.absolute(packagePath));
  final formatName = results.option('format')!;
  final format = ApiSummaryFormat.values.byName(formatName);

  switch ((
    write: results.flag('write'),
    check: results.flag('check'),
    output: results.option('output'),
  )) {
    case (write: true, check: true, output: _):
      throw const FormatException('Cannot specify both --write and --check.');
    case (write: true, check: false, output: _?):
      throw const FormatException('Cannot specify both --write and --output.');
    case (write: false, check: true, output: _?):
      throw const FormatException('Cannot specify both --check and --output.');
    case (write: false, check: true, output: null):
      await expectApiSummaryClean(packagePath: absolutePath, format: format);
    case (write: false, check: false, output: null):
      final package = await apiSummary(absolutePath);
      stdout.write(format.format(package));
    case (write: true, check: false, output: null):
      final package = await apiSummary(absolutePath);
      _writeOutputFile(
        p.join(absolutePath, format.defaultFileName),
        format.format(package),
      );
    case (write: false, check: false, output: final outputPath?):
      final package = await apiSummary(absolutePath);
      final targetPath = p.isAbsolute(outputPath)
          ? p.normalize(outputPath)
          : p.normalize(p.join(absolutePath, outputPath));
      _writeOutputFile(targetPath, format.format(package));
  }
}

void _writeOutputFile(String targetPath, String content) {
  final outFile = File(targetPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(content);
}

final _parser = ArgParser()
  ..addOption(
    'package-path',
    abbr: 'p',
    help:
        'The path to the package to summarize. Defaults to the current '
        'directory.',
  )
  ..addOption(
    'format',
    abbr: 'f',
    help: 'The output format for the summary.',
    allowed: [for (final f in ApiSummaryFormat.values) f.name],
    defaultsTo: ApiSummaryFormat.text.name,
  )
  ..addOption(
    'output',
    abbr: 'o',
    help: 'Write the summary to a file path instead of stdout.',
  )
  ..addFlag(
    'write',
    abbr: 'w',
    help:
        'Write the summary to the default golden file (api.txt, api.json, or '
        'api.yaml) in the package directory.',
    negatable: false,
  )
  ..addFlag(
    'check',
    abbr: 'c',
    help:
        'Verify that the golden file (api.txt, api.json, or api.yaml) matches '
        'the current public API.',
    negatable: false,
  )
  ..addFlag(
    'help',
    abbr: 'h',
    help: 'Print this usage information.',
    negatable: false,
  );
