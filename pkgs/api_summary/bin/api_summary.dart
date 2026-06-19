// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:api_summary/api_summary.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

Future<void> main(List<String> arguments) async {
  try {
    final results = parser.parse(arguments);

    if (results.flag('help')) {
      print('Usage: api_summary [options]');
      print(parser.usage);
      return;
    }

    final packagePath =
        results.option('package-path') ?? Directory.current.path;
    final absolutePath = p.normalize(p.absolute(packagePath));

    final format = results.option('format');
    final package = await apiSummary(absolutePath);
    switch (format) {
      case 'json':
        final summary = const JsonEncoder.withIndent(
          '  ',
        ).convert(package.toJson());
        stdout.writeln(summary);
      case 'yaml':
        final editor = YamlEditor('');
        editor.update([], package.toJson());
        stdout.writeln(editor.toString());
      case 'text':
        stdout.write(package.toString());
      default:
        throw UnsupportedError('Unsupported output format: $format');
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('\nUsage: api_summary [options]');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
    // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('\nUsage: api_summary [options]');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }
}

final parser = ArgParser()
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
