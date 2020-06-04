// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;

/// [Environment] stores gathered arguments information.
class Environment {
  String sdkRoot;
  String pkgRoot;
  String packagesPath;
  String baseDirectory;
  String input;
  IOSink output;
  List<String> reportOn;
  String bazelWorkspace;
  bool bazel;
  int workers;
  bool prettyPrint;
  bool lcov;
  bool expectMarkers;
  bool verbose;
}

Future<Null> main(List<String> arguments) async {
  final env = parseArgs(arguments);

  final files = filesToProcess(env.input);
  if (env.verbose) {
    print('Environment:');
    print('  # files: ${files.length}');
    print('  # workers: ${env.workers}');
    print('  sdk-root: ${env.sdkRoot}');
    print('  package-root: ${env.pkgRoot}');
    print('  package-spec: ${env.packagesPath}');
    print('  report-on: ${env.reportOn}');
  }

  final clock = Stopwatch()..start();
  final hitmap = await parseCoverage(files, env.workers);

  // All workers are done. Process the data.
  if (env.verbose) {
    print('Done creating global hitmap. Took ${clock.elapsedMilliseconds} ms.');
  }

  String output;
  final resolver = env.bazel
      ? BazelResolver(workspacePath: env.bazelWorkspace)
      : Resolver(
          packagesPath: env.packagesPath,
          // ignore_for_file: deprecated_member_use_from_same_package
          packageRoot: env.pkgRoot,
          sdkRoot: env.sdkRoot);
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
  final env = Environment();
  final parser = ArgParser();

  parser.addOption('sdk-root', abbr: 's', help: 'path to the SDK root');
  parser.addOption('package-root', abbr: 'p', help: 'path to the package root');
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
  parser.addFlag('help', abbr: 'h', negatable: false, help: 'show this help');

  final args = parser.parse(arguments);

  void printUsage() {
    print('Usage: dart format_coverage.dart [OPTION...]\n');
    print(parser.usage);
  }

  void fail(String msg) {
    print('\n$msg\n');
    printUsage();
    exit(1);
  }

  if (args['help'] as bool) {
    printUsage();
    exit(0);
  }

  env.sdkRoot = args['sdk-root'] as String;
  if (env.sdkRoot != null) {
    env.sdkRoot = p.normalize(p.join(p.absolute(env.sdkRoot), 'lib'));
    if (!FileSystemEntity.isDirectorySync(env.sdkRoot)) {
      fail('Provided SDK root "${args["sdk-root"]}" is not a valid SDK '
          'top-level directory');
    }
  }

  if (args['package-root'] != null && args['packages'] != null) {
    fail('Only one of --package-root or --packages may be specified.');
  }

  env.packagesPath = args['packages'] as String;
  if (env.packagesPath != null) {
    if (!FileSystemEntity.isFileSync(env.packagesPath)) {
      fail('Package spec "${args["packages"]}" not found, or not a file.');
    }
  }

  env.pkgRoot = args['package-root'] as String;
  if (env.pkgRoot != null) {
    env.pkgRoot = p.absolute(p.normalize(args['package-root'] as String));
    if (!FileSystemEntity.isDirectorySync(env.pkgRoot)) {
      fail('Package root "${args["package-root"]}" is not a directory.');
    }
  }

  if (args['in'] == null) fail('No input files given.');
  env.input = p.absolute(p.normalize(args['in'] as String));
  if (!FileSystemEntity.isDirectorySync(env.input) &&
      !FileSystemEntity.isFileSync(env.input)) {
    fail('Provided input "${args["in"]}" is neither a directory nor a file.');
  }

  if (args['out'] == 'stdout') {
    env.output = stdout;
  } else {
    final outpath = p.absolute(p.normalize(args['out'] as String));
    final outfile = File(outpath)..createSync(recursive: true);
    env.output = outfile.openWrite();
  }

  final reportOn = args['report-on'] as List<String>;
  env.reportOn = reportOn.isNotEmpty ? reportOn : null;

  env.bazel = args['bazel'] as bool;
  env.bazelWorkspace = args['bazel-workspace'] as String;
  if (env.bazelWorkspace.isNotEmpty && !env.bazel) {
    stderr.writeln('warning: ignoring --bazel-workspace: --bazel not set');
  }

  if (args['base-directory'] != null) {
    env.baseDirectory = p.absolute(args['base-directory'] as String);
  }

  env.lcov = args['lcov'] as bool;
  if (args['pretty-print'] as bool && env.lcov) {
    fail('Choose one of pretty-print or lcov output');
  }
  // Use pretty-print either explicitly or by default.
  env.prettyPrint = !env.lcov;

  try {
    env.workers = int.parse('${args["workers"]}');
  } catch (e) {
    fail('Invalid worker count: $e');
  }

  env.verbose = args['verbose'] as bool;
  return env;
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
