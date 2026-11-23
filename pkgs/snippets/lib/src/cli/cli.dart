// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// `dart run snippets@ …`
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../diagnostic.dart';
import '../runner.dart';

part 'cli.update.dart';
part 'cli.validate.dart';

CommandRunner<int> _commandRunner({
  required StringSink out,
  required StringSink err,
}) {
  final runner = CommandRunner<int>(
    'snippets',
    'Keep the code samples in your markdown up to date with real programs.',
  )
    ..argParser.addOption(
      'directory',
      abbr: 'C',
      help: 'Run in this directory instead of the current one.',
      valueHelp: 'folder',
    )
    ..addCommand(_UpdateCommand(out: out, err: err))
    ..addCommand(_ValidateCommand(out: out, err: err));
  return runner;
}

/// Runs the CLI and returns the process exit code.
Future<int> runSnippets(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
}) async {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  try {
    return await _commandRunner(out: stdoutSink, err: stderrSink)
            .run(arguments) ??
        0;
  } on UsageException catch (e) {
    stderrSink.writeln(e);
    return 64; // EX_USAGE
  } on FileSystemException catch (e) {
    stderrSink.writeln(e);
    return 1;
  }
}

abstract base class _Base extends Command<int> {
  final StringSink out;
  final StringSink err;

  _Base({required this.out, required this.err}) {
    // Also accepted before the command name, because both spellings are the
    // first thing people try.
    argParser.addOption(
      'directory',
      abbr: 'C',
      help: 'Run in this directory instead of the current one.',
      valueHelp: 'folder',
    );
  }

  String get directory =>
      argResults?.option('directory') ??
      globalResults?.option('directory') ??
      Directory.current.path;

  /// Prints [diagnostics] to [err] and returns whether there were any errors.
  bool report(List<ExampleFormatException> diagnostics) {
    final color = identical(err, stderr) && stderr.supportsAnsiEscapes;
    for (final diagnostic in diagnostics) {
      err.writeln(diagnostic.toString(color: color));
    }
    return diagnostics.isNotEmpty;
  }
}
