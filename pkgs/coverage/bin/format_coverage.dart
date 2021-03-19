// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/coverage.dart';
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
    required this.prettyPrint,
    required this.reportOn,
    required this.sdkRoot,
    required this.verbose,
    required this.workers,
  });

  String? baseDirectory;
  bool bazel;
  String bazelWorkspace;
  bool checkIgnore;
  String input;
  bool lcov;
  IOSink output;
  String? packagesPath;
  bool prettyPrint;
  List<String>? reportOn;
  String? sdkRoot;
  bool verbose;
  int workers;
}

Future<Null> main(List<String> arguments) async {
  final env = parseArgs(arguments);

  final files = filesToProcess(env.input);
  if (env.verbose) {
    print('Environment:');
    print('  # files: ${files.length}');
    print('  # workers: ${env.workers}');
    print('  sdk-root: ${env.sdkRoot}');
    print('  package-spec: ${env.packagesPath}');
    print('  report-on: ${env.reportOn}');
    print('  check-ignore: ${env.checkIgnore}');
  }

  final clock = Stopwatch()..start();
  final hitmap = await parseCoverage(
    files,
    env.workers,
    checkIgnoredLines: env.checkIgnore,
    packagesPath: env.packagesPath,
  );

  // All workers are done. Process the data.
  if (env.verbose) {
    print('Done creating global hitmap. Took ${clock.elapsedMilliseconds} ms.');
  }

  String output;
  final resolver = env.bazel
      ? BazelResolver(workspacePath: env.bazelWorkspace)
      : Resolver(packagesPath: env.packagesPath, sdkRoot: env.sdkRoot);
  final loader = Loader();
  if (env.prettyPrint) {
    output =
        await PrettyPrintFormatter(resolver, loader, reportOn: env.reportOn)
            .format(hitmap);
  } else {
    assert(env.lcov);
    output = await LcovFormatter(resolver,
            reportOn: env.reportOn, basePath: env.baseDirectory)
        .format(hitmap);
  }

  env.output.write(output);
  await env.output.flush();
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
  await env.output.close();
}

/// Checks the validity of the provided arguments. Does not initialize actual
/// processing.
Environment parseArgs(List<String> arguments) {
  final parser = ArgParser();

  parser.addOption('sdk-root', abbr: 's', help: 'path to the SDK root');
  parser.addOption('packages', help: 'path to the package spec file');
  parser.addOption('in', abbr: 'i', help: 'input(s): may be file or directory');
  parser.addOption('out',
      abbr: 'o', defaultsTo: 'stdout', help: 'output: may be file or stdout');
  parser.addMultiOption('report-on',
      help: 'which directories or files to report coverage on');
  parser.addOption('workers',
      abbr: 'j', defaultsTo: '1', help: 'number of workers');
  parser.addOption('bazel-workspace',
      defaultsTo: '', help: 'Bazel workspace directory');
  parser.addOption('base-directory',
      abbr: 'b',
      help: 'the base directory relative to which source paths are output');
  parser.addFlag('bazel',
      defaultsTo: false, help: 'use Bazel-style path resolution');
  parser.addFlag('pretty-print',
      abbr: 'r',
      negatable: false,
      help: 'convert coverage data to pretty print format');
  parser.addFlag('lcov',
      abbr: 'l',
      negatable: false,
      help: 'convert coverage data to lcov format');
  parser.addFlag('verbose',
      abbr: 'v', negatable: false, help: 'verbose output');
  parser.addFlag(
    'check-ignore',
    abbr: 'c',
    negatable: false,
    help: 'check for coverage ignore comments.'
        ' Not supported in web coverage.',
  );
  parser.addFlag('help', abbr: 'h', negatable: false, help: 'show this help');

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

  if (args['in'] == null) fail('No input files given.');
  final input = p.absolute(p.normalize(args['in'] as String));
  if (!FileSystemEntity.isDirectorySync(input) &&
      !FileSystemEntity.isFileSync(input)) {
    fail('Provided input "${args["in"]}" is neither a directory nor a file.');
  }

  IOSink output;
  if (args['out'] == 'stdout') {
    output = stdout;
  } else {
    final outpath = p.absolute(p.normalize(args['out'] as String));
    final outfile = File(outpath)..createSync(recursive: true);
    output = outfile.openWrite();
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
  if (args['pretty-print'] as bool && lcov == true) {
    fail('Choose one of pretty-print or lcov output');
  }

  // Use pretty-print either explicitly or by default.
  final prettyPrint = !lcov;

  int workers;
  try {
    workers = int.parse('${args["workers"]}');
  } catch (e) {
    fail('Invalid worker count: $e');
  }

  final checkIgnore = args['check-ignore'] as bool;
  final verbose = args['verbose'] as bool;
  return Environment(
      baseDirectory: baseDirectory,
      bazel: bazel,
      bazelWorkspace: bazelWorkspace,
      checkIgnore: checkIgnore,
      input: input,
      lcov: lcov,
      output: output,
      packagesPath: packagesPath,
      prettyPrint: prettyPrint,
      reportOn: reportOn,
      sdkRoot: sdkRoot,
      verbose: verbose,
      workers: workers);
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
