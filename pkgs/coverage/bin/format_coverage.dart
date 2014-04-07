// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/coverage.dart';
import 'package:path/path.dart';


/// [Environment] stores gathered arguments information.
class Environment {
  String sdkRoot;
  String pkgRoot;
  String input;
  IOSink output;
  int workers;
  bool prettyPrint;
  bool lcov;
  bool expectMarkers;
  bool verbose;
}

main(List<String> arguments) {
  final env = parseArgs(arguments);

  List files = filesToProcess(env.input);
  int start = new DateTime.now().millisecondsSinceEpoch;
  if (env.verbose) {
    print('Environment:');
    print('  # files: ${files.length}');
    print('  # workers: ${env.workers}');
    print('  sdk-root: ${env.sdkRoot}');
    print('  package-root: ${env.pkgRoot}');
  }

  parseCoverage(files, env.workers).then((hitmap) {
    // All workers are done. Process the data.
    if (env.verbose) {
      final end = new DateTime.now().millisecondsSinceEpoch;
      print('Done creating a global hitmap. Took ${end - start} ms.');
    }

    List failedResolves = [];
    List failedLoads = [];
    Future out;
    var resolver = new Resolver(packageRoot: env.pkgRoot, sdkRoot: env.sdkRoot);
    var loader = new Loader();
    if (env.prettyPrint) {
      out = prettyPrint(hitmap, resolver, loader, env.output,
          failedResolves, failedLoads);
    } else if (env.lcov) {
      out = lcov(hitmap, resolver, env.output, failedResolves);
    }

    out.then((_) {
      env.output.close().then((_) {
        if (env.verbose) {
          final end = new DateTime.now().millisecondsSinceEpoch;
          print('Done flushing output. Took ${end - start} ms.');
        }
      });

      if (env.verbose) {
        if (failedResolves.length > 0) {
          print('Failed to resolve:');
          failedResolves.toSet().forEach((e) {
            print('  ${e}');
          });
        }
        if (failedLoads.length > 0) {
          print('Failed to load:');
          failedLoads.toSet().forEach((e) {
            print('  ${e}');
          });
        }
      }
    });
  });
}

/// Checks the validity of the provided arguments. Does not initialize actual
/// processing.
parseArgs(List<String> arguments) {
  final env = new Environment();
  var parser = new ArgParser();

  parser.addOption('sdk-root', abbr: 's',
      help: 'path to the SDK root');
  parser.addOption('package-root', abbr: 'p',
      help: 'path to the package root');
  parser.addOption('in', abbr: 'i',
      help: 'input(s): may be file or directory');
  parser.addOption('out', abbr: 'o', defaultsTo: 'stdout',
      help: 'output: may be file or stdout');
  parser.addOption('workers', abbr: 'j', defaultsTo: '1',
      help: 'number of workers');
  parser.addFlag('pretty-print', abbr: 'r', negatable: false,
      help: 'convert coverage data to pretty print format');
  parser.addFlag('lcov', abbr :'l', negatable: false,
      help: 'convert coverage data to lcov format');
  parser.addFlag('verbose', abbr :'v', negatable: false,
      help: 'verbose output');
  parser.addFlag('help', abbr: 'h', negatable: false,
      help: 'show this help');

  var args = parser.parse(arguments);

  printUsage() {
    print('Usage: dart format_coverage.dart [OPTION...]\n');
    print(parser.getUsage());
  }

  fail(String msg) {
    print('\n$msg\n');
    printUsage();
    exit(1);
  }

  if (args['help']) {
    printUsage();
    exit(0);
  }

  env.sdkRoot = args['sdk-root'];
  if (env.sdkRoot == null) {
    if (Platform.environment.containsKey('DART_SDK')) {
      env.sdkRoot =
        join(absolute(normalize(Platform.environment['DART_SDK'])), 'lib');
    }
  } else {
    env.sdkRoot = join(absolute(normalize(env.sdkRoot)), 'lib');
  }
  if ((env.sdkRoot != null) && !FileSystemEntity.isDirectorySync(env.sdkRoot)) {
    fail('Provided SDK root "${args["sdk-root"]}" is not a valid SDK '
         'top-level directory');
  }

  env.pkgRoot = args['package-root'];
  if (env.pkgRoot != null) {
    env.pkgRoot = absolute(normalize(args['package-root']));
    if (!FileSystemEntity.isDirectorySync(env.pkgRoot)) {
      fail('Provided package root "${args["package-root"]}" is not directory.');
    }
  }

  if (args['in'] == null) fail('No input files given.');
  env.input = absolute(normalize(args['in']));
  if (!FileSystemEntity.isDirectorySync(env.input) &&
      !FileSystemEntity.isFileSync(env.input)) {
    fail('Provided input "${args["in"]}" is neither a directory nor a file.');
  }

  if (args['out'] == 'stdout') {
    env.output = stdout;
  } else {
    var outpath = absolute(normalize(args['out']));
    var outfile = new File(outpath)
        ..createSync(recursive: true);
    env.output = outfile.openWrite();
  }

  env.lcov = args['lcov'];
  if (args['pretty-print'] && env.lcov) {
    fail('Choose one of pretty-print or lcov output');
  }
  if (!env.lcov) {
    // Use pretty-print either explicitly or by default.
    env.prettyPrint = true;
  }

  try {
    env.workers = int.parse('${args["workers"]}');
  } catch (e) {
    fail('Invalid worker count: $e');
  }

  env.verbose = args['verbose'];
  return env;
}

/// Given an absolute path absPath, this function returns a [List] of files
/// are contained by it if it is a directory, or a [List] containing the file if
/// it is a file.
List filesToProcess(String absPath) {
  var filePattern = new RegExp(r'^dart-cov-\d+-\d+.json$');
  if (FileSystemEntity.isDirectorySync(absPath)) {
    return new Directory(absPath).listSync(recursive: true)
        .where((e) => e is File && filePattern.hasMatch(basename(e.path)))
        .toList();
  }
  return [new File(absPath)];
}
