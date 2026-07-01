// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_catching_errors

import 'dart:convert';
import 'dart:io';

import 'package:api_summary/api_summary.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

Future<void> main(List<String> arguments) async {
  try {
    final results = _parser.parse(arguments);

    if (results.flag('help')) {
      print('Usage: api_summary [options]');
      print(_parser.usage);
      return;
    }

    final packagePath =
        results.option('package-path') ?? Directory.current.path;
    final absolutePath = p.normalize(p.absolute(packagePath));

    final format = results.option('format');
    final package = await apiSummary(absolutePath);
    print(_format(package, format!));
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('\nUsage: api_summary [options]');
    stderr.writeln(_parser.usage);
    exitCode = 64;
    return;
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('\nUsage: api_summary [options]');
    stderr.writeln(_parser.usage);
    exitCode = 64;
    return;
  }
}

String _format(ApiSummary package, String format) => switch (format) {
  'text' => package.toString(),
  'json' => _formatJson(package),
  'yaml' => _formatYaml(package),
  _ => throw UnsupportedError('Unsupported output format: $format'),
};

String _formatYaml(ApiSummary package) {
  final editor = YamlEditor('');
  editor.update([], package.toJson());
  return '$editor\n';
}

String _formatJson(ApiSummary package) =>
    '${const JsonEncoder.withIndent('  ').convert(package.toJson())}\n';

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
    allowed: ['text', 'json', 'yaml'],
    defaultsTo: 'text',
  )
  ..addFlag(
    'help',
    abbr: 'h',
    help: 'Print this usage information.',
    negatable: false,
  );
