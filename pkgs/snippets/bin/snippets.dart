// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:snippets/snippets.dart';

void main(final List<String> args) async {
  await runSnippets(args);
}

/// Run the code snippets tool with the specified [arguments],
/// usually meant to be called from a command-line app.
Future<void> runSnippets(final List<String> arguments) async {
  final ArgResults results;
  try {
    results = _argParser.parse(arguments);
  } on FormatException catch (e) {
    _printUsageAndExit(message: e.message);
  }

  final dryRun = results.flag(_dryRunFlag);
  final failOnUpdate = results.flag(_failOnUpdateFlag);
  final excludePaths = results.multiOption(_excludeOption);
  final plasterContent = results.option(_plasterContentOption) ?? '...';
  final replaceInstructions = results.option(_replaceOption);
  final baseSourcePath = path.absolute(
    results.option(_baseSourcePathOption) ?? path.current,
  );

  if (results.rest.length != 1) {
    _printUsageAndExit(
      message: 'You must specify a file or directory to run updates on.',
    );
  }
  final updatePath = path.absolute(results.rest.first);

  final replaceTransforms = replaceInstructions == null
      ? const <ReplaceTransform>[]
      : stringToReplaceTransforms(
          replaceInstructions,
          (e) => _printUsageAndExit(message: e),
        );

  final updater = Updater(
    baseSourcePath: baseSourcePath,
    validTargetExtensions: const {'.md'},
    defaultPlasterContent: plasterContent,
    defaultTransforms: replaceTransforms,
    excludePaths: excludePaths.map(RegExp.new),
  );

  final result = await updater.update(updatePath, makeUpdates: !dryRun);
  if (result.warnings.isNotEmpty || result.errors.isNotEmpty) {
    for (final error in result.errors) {
      print('  error - $error');
    }
    for (final warning in result.warnings) {
      print('warning - $warning');
    }
    print('');
    print(
      '${result.errors.length} errors and '
      '${result.warnings.length} warnings found!',
    );
    print('');
  }

  print(
    'Processed ${result.filesVisited} out of '
    '${result.totalFilesToVisit} files: '
    '${result.excerptsNeedingUpdates} out of '
    '${result.excerptsVisited} excerpts visited '
    '${result.madeUpdates ? 'were updated' : 'need to be updated'}.',
  );

  if (result.errors.isNotEmpty) {
    io.exitCode = 1;
  } else if (failOnUpdate && result.excerptsNeedingUpdates > 0) {
    io.exitCode = 1;
  }
}

final _argParser = ArgParser()
  ..addFlag(
    _dryRunFlag,
    negatable: false,
    help: 'If the updater should only report if excerpts need to be updated.',
  )
  ..addFlag(
    _failOnUpdateFlag,
    negatable: false,
    help:
        'Report a non-zero exit code if '
        'an excerpt is or needs to be updated.',
  )
  ..addMultiOption(
    _excludeOption,
    help:
        'Regular expressions of paths to exclude when '
        'processing a directory recursively.\n'
        'Dot files and directories are always excluded.',
  )
  ..addOption(
    _baseSourcePathOption,
    help:
        'The path to the directory containing the source files that '
        'excerpt regions should be retrieved from.',
  )
  ..addOption(
    _plasterContentOption,
    help: 'The default plaster content, such as "..." or "···".',
  )
  ..addOption(
    _replaceOption,
    help:
        'A replacement to run on every excerpt.\n'
        'Refer to the package docs for syntax help.',
  );

/// Print the usage information for this command,
/// optionally with the specified error [message] and [exitCode],
/// then exit.
///
/// If no [exitCode] is specified, exit with a code of `1`, indicating failure.
Never _printUsageAndExit({String? message, int exitCode = 1}) {
  if (message != null) print('\n$message\n');
  print('Usage: snippets [OPTIONS] file_or_directory\n');
  print(_argParser.usage);
  io.exit(exitCode);
}

const String _dryRunFlag = 'dry-run';
const String _failOnUpdateFlag = 'fail-on-update';
const String _excludeOption = 'exclude';
const String _plasterContentOption = 'plaster-content';
const String _replaceOption = 'replace';
const String _baseSourcePathOption = 'base-source';
