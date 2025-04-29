// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/coverage.dart';
import 'package:coverage/src/coverage_options.dart';
import 'package:coverage/src/coverage_percentage.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// [Environment] stores gathered arguments information.
class Environment {
  Environment({
    required this.baseDirectory,
    required this.bazel,
    required this.bazelWorkspace,
    required this.checkIgnore,
    required this.input,
    required this.lcov,
    required this.output,
    required this.packagesPath,
    required this.packagePath,
    required this.prettyPrint,
    required this.prettyPrintFunc,
    required this.prettyPrintBranch,
    required this.reportOn,
    required this.ignoreFiles,
    required this.sdkRoot,
    required this.verbose,
    required this.workers,
    required this.failUnder,
  });

  String? baseDirectory;
  bool bazel;
  String bazelWorkspace;
  bool checkIgnore;
  String input;
  bool lcov;
  String? output;
  String? packagesPath;
  String packagePath;
  bool prettyPrint;
  bool prettyPrintFunc;
  bool prettyPrintBranch;
  List<String>? reportOn;
  List<String>? ignoreFiles;
  String? sdkRoot;
  bool verbose;
  int workers;
  double? failUnder;
}

Future<void> main(List<String> arguments) async {
  final defaultOptions = CoverageOptionsProvider().coverageOptions;
  final env = parseArgs(arguments, defaultOptions);

  final files = filesToProcess(env.input);
  if (env.verbose) {
    print('Environment:');
    print('  # files: ${files.length}');
    print('  # workers: ${env.workers}');
    print('  sdk-root: ${env.sdkRoot}');
    print('  package-path: ${env.packagePath}');
    print('  packages-path: ${env.packagesPath}');
    print('  report-on: ${env.reportOn}');
    print('  check-ignore: ${env.checkIgnore}');
  }

  final clock = Stopwatch()..start();
  final hitmap = await HitMap.parseFiles(
    files,
    checkIgnoredLines: env.checkIgnore,
    // ignore: deprecated_member_use_from_same_package
    packagesPath: env.packagesPath,
    packagePath: env.packagePath,
  );

  // All workers are done. Process the data.
  if (env.verbose) {
    print('Done creating global hitmap. Took ${clock.elapsedMilliseconds} ms.');
  }

  final ignoreGlobs = env.ignoreFiles?.map(Glob.new).toSet();

  String output;
  final resolver = env.bazel
      ? BazelResolver(workspacePath: env.bazelWorkspace)
      : await Resolver.create(
          packagesPath: env.packagesPath,
          packagePath: env.packagePath,
          sdkRoot: env.sdkRoot,
        );
  final loader = Loader();
  if (env.prettyPrint) {
    output = await hitmap.prettyPrint(resolver, loader,
        reportOn: env.reportOn,
        ignoreGlobs: ignoreGlobs,
        reportFuncs: env.prettyPrintFunc,
        reportBranches: env.prettyPrintBranch);
  } else {
    assert(env.lcov);
    output = hitmap.formatLcov(resolver,
        reportOn: env.reportOn,
        ignoreGlobs: ignoreGlobs,
        basePath: env.baseDirectory);
  }

  final outputSink =
      env.output == null ? stdout : File(env.output!).openWrite();

  outputSink.write(output);
  await outputSink.flush();
  if (env.verbose) {
    print('Done flushing output. Took ${clock.elapsedMilliseconds} ms.');
  }

  if (env.verbose) {
    if (resolver.failed.isNotEmpty) {
      print('Failed to resolve:');
      for (var error in resolver.failed.toSet()) {
        print('  $error');
      }
    }
    if (loader.failed.isNotEmpty) {
      print('Failed to load:');
      for (var error in loader.failed.toSet()) {
        print('  $error');
      }
    }
  }
  await outputSink.close();

  // Check coverage against the fail-under threshold if specified.
  final failUnder = env.failUnder;
  if (failUnder != null) {
    // Calculate the overall coverage percentage using the utility function.
    final result = calculateCoveragePercentage(
      hitmap,
    );

    if (env.verbose) {
      print('Coverage: ${result.percentage.toStringAsFixed(2)}% '
          '(${result.coveredLines} of ${result.totalLines} lines)');
    }

    if (result.percentage < failUnder) {
      print('Error: Coverage ${result.percentage.toStringAsFixed(2)}% '
          'is less than required ${failUnder.toStringAsFixed(2)}%');
      exit(1);
    } else if (env.verbose) {
      print('Coverage ${result.percentage.toStringAsFixed(2)}% meets or exceeds'
          'the required ${failUnder.toStringAsFixed(2)}%');
    }
  }
}

/// Checks the validity of the provided arguments. Does not initialize actual
/// processing.
Environment parseArgs(List<String> arguments, CoverageOptions defaultOptions) {
  final parser = ArgParser();

  parser
    ..addOption(
      'sdk-root',
      abbr: 's',
      help: 'path to the SDK root',
    )
    ..addOption(
      'fail-under',
      help: 'Fail if coverage is less than the given percentage (0-100)',
    )
    ..addOption(
      'packages',
      help: '[DEPRECATED] path to the package spec file',
    )
    ..addOption('package',
        help: 'root directory of the package',
        defaultsTo: defaultOptions.packageDirectory)
    ..addOption(
      'in',
      abbr: 'i',
      help: 'input(s): may be file or directory',
    )
    ..addOption('out', abbr: 'o', help: 'output: may be file or stdout')
    ..addMultiOption(
      'report-on',
      help: 'which directories or files to report coverage on',
    )
    ..addOption(
      'workers',
      abbr: 'j',
      defaultsTo: '1',
      help: 'number of workers',
    )
    ..addOption('bazel-workspace',
        defaultsTo: '', help: 'Bazel workspace directory')
    ..addOption('base-directory',
        abbr: 'b',
        help: 'the base directory relative to which source paths are output')
    ..addFlag('bazel',
        defaultsTo: false, help: 'use Bazel-style path resolution')
    ..addFlag('pretty-print',
        abbr: 'r',
        negatable: false,
        help: 'convert line coverage data to pretty print format')
    ..addFlag('pretty-print-func',
        abbr: 'f',
        negatable: false,
        help: 'convert function coverage data to pretty print format')
    ..addFlag('pretty-print-branch',
        negatable: false,
        help: 'convert branch coverage data to pretty print format')
    ..addFlag('lcov',
        abbr: 'l',
        negatable: false,
        help: 'convert coverage data to lcov format')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'verbose output')
    ..addFlag(
      'check-ignore',
      abbr: 'c',
      negatable: false,
      help: 'check for coverage ignore comments.'
          ' Not supported in web coverage.',
    )
    ..addMultiOption(
      'ignore-files',
      defaultsTo: [],
      help: 'Ignore files by glob patterns',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'show this help');

  final args = parser.parse(arguments);

  void printUsage() {
    print('Usage: dart format_coverage.dart [OPTION...]\n');
    print(parser.usage);
  }

  Never fail(String msg) {
    print('\n$msg\n');
    printUsage();
    exit(1);
  }

  if (args['help'] as bool) {
    printUsage();
    exit(0);
  }

  var sdkRoot = args['sdk-root'] as String?;
  if (sdkRoot != null) {
    sdkRoot = p.normalize(p.join(p.absolute(sdkRoot), 'lib'));
    if (!FileSystemEntity.isDirectorySync(sdkRoot)) {
      fail('Provided SDK root "${args["sdk-root"]}" is not a valid SDK '
          'top-level directory');
    }
  }

  final packagesPath = args['packages'] as String?;
  if (packagesPath != null) {
    if (!FileSystemEntity.isFileSync(packagesPath)) {
      fail('Package spec "${args["packages"]}" not found, or not a file.');
    }
  }

  final packagePath = args['package'] as String;
  if (!FileSystemEntity.isDirectorySync(packagePath)) {
    fail('Package spec "${args["package"]}" not found, or not a directory.');
  }

  if (args['in'] == null && defaultOptions.outputDirectory == null) {
    fail('No input files given.');
  }
  final input = p.normalize((args['in'] as String?) ??
      p.absolute(defaultOptions.outputDirectory!, 'coverage.json'));
  if (!FileSystemEntity.isDirectorySync(input) &&
      !FileSystemEntity.isFileSync(input)) {
    fail('Provided input "${args["in"]}" is neither a directory nor a file.');
  }

  String? output;
  final outPath = args['out'] as String?;
  if (outPath == 'stdout' ||
      (outPath == null && defaultOptions.outputDirectory == null)) {
    output = null;
  } else {
    final outFilePath = p.normalize(
        outPath ?? p.absolute(defaultOptions.outputDirectory!, 'lcov.info'));

    final outfile = File(outFilePath);
    if (!FileSystemEntity.isDirectorySync(outFilePath) &&
        !FileSystemEntity.isFileSync(outFilePath)) {
      outfile.createSync(recursive: true);
    }
    output = outfile.path;
  }

  final reportOnRaw = args['report-on'] as List<String>;
  final reportOn = reportOnRaw.isNotEmpty ? reportOnRaw : null;

  final bazel = args['bazel'] as bool;
  final bazelWorkspace = args['bazel-workspace'] as String;
  if (bazelWorkspace.isNotEmpty && !bazel) {
    stderr.writeln('warning: ignoring --bazel-workspace: --bazel not set');
  }

  String? baseDirectory;
  if (args['base-directory'] != null) {
    baseDirectory = p.absolute(args['base-directory'] as String);
  }

  final lcov = args['lcov'] as bool;
  var prettyPrint = args['pretty-print'] as bool;
  final prettyPrintFunc = args['pretty-print-func'] as bool;
  final prettyPrintBranch = args['pretty-print-branch'] as bool;
  final numModesChosen = (prettyPrint ? 1 : 0) +
      (prettyPrintFunc ? 1 : 0) +
      (prettyPrintBranch ? 1 : 0) +
      (lcov ? 1 : 0);
  if (numModesChosen > 1) {
    fail('Choose one of the pretty-print modes or lcov output');
  }

  // The pretty printer is used by all modes other than lcov.
  if (!lcov) prettyPrint = true;

  int workers;
  try {
    workers = int.parse('${args["workers"]}');
  } catch (e) {
    fail('Invalid worker count: $e');
  }

  final checkIgnore = args['check-ignore'] as bool;
  final ignoredGlobs = args['ignore-files'] as List<String>;
  final verbose = args['verbose'] as bool;

  double? failUnder;
  final failUnderStr = args['fail-under'] as String?;
  if (failUnderStr != null) {
    try {
      failUnder = double.parse(failUnderStr);
      if (failUnder < 0 || failUnder > 100) {
        fail('--fail-under must be a percentage between 0 and 100');
      }
    } catch (e) {
      fail('Invalid --fail-under value: $e');
    }
  }

  return Environment(
    baseDirectory: baseDirectory,
    bazel: bazel,
    bazelWorkspace: bazelWorkspace,
    checkIgnore: checkIgnore,
    input: input,
    lcov: lcov,
    output: output,
    packagesPath: packagesPath,
    packagePath: packagePath,
    prettyPrint: prettyPrint,
    prettyPrintFunc: prettyPrintFunc,
    prettyPrintBranch: prettyPrintBranch,
    reportOn: reportOn,
    ignoreFiles: ignoredGlobs,
    sdkRoot: sdkRoot,
    verbose: verbose,
    workers: workers,
    failUnder: failUnder,
  );
}

/// Given an absolute path absPath, this function returns a [List] of files
/// are contained by it if it is a directory, or a [List] containing the file if
/// it is a file.
List<File> filesToProcess(String absPath) {
  if (FileSystemEntity.isDirectorySync(absPath)) {
    return Directory(absPath)
        .listSync(recursive: true)
        .whereType<File>()
        .where((e) => e.path.endsWith('.json'))
        .toList();
  }
  return <File>[File(absPath)];
}
