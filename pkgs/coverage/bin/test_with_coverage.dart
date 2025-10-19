// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/src/coverage_options.dart';
import 'package:coverage/src/util.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'collect_coverage.dart' as collect_coverage;
import 'format_coverage.dart' as format_coverage;

final _allProcesses = <Process>[];

Future<void> _dartRun(List<String> args,
    {required void Function(String) onStdout,
    required void Function(String) onStderr}) async {
  final process = await Process.start(Platform.executable, args);
  _allProcesses.add(process);

  void listen(
      Stream<List<int>> stream, IOSink sink, void Function(String) onLine) {
    final broadStream = stream.asBroadcastStream();
    broadStream.listen(sink.add);
    broadStream.lines().listen(onLine);
  }

  listen(process.stdout, stdout, onStdout);
  listen(process.stderr, stderr, onStderr);

  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(Platform.executable, args, '', result);
  }
}

void _killSubprocessesAndExit(ProcessSignal signal) {
  for (final process in _allProcesses) {
    process.kill(signal);
  }
  exit(1);
}

void _watchExitSignal(ProcessSignal signal) {
  signal.watch().listen(_killSubprocessesAndExit);
}

ArgParser _createArgParser(CoverageOptions defaultOptions) => ArgParser()
  ..addOption(
    'package',
    help: 'Root directory of the package to test.',
    defaultsTo: defaultOptions.packageDirectory,
  )
  ..addOption(
    'package-name',
    help: 'Name of the package to test. '
        'Deduced from --package if not provided. '
        'DEPRECATED: use --scope-output',
  )
  ..addOption('port', help: 'VM service port. Defaults to using any free port.')
  ..addOption(
    'out',
    defaultsTo: defaultOptions.outputDirectory,
    abbr: 'o',
    help: 'Output directory. Defaults to <package-dir>/coverage.',
  )
  ..addOption('test',
      help: 'Test script to run.', defaultsTo: defaultOptions.testScript)
  ..addFlag(
    'function-coverage',
    abbr: 'f',
    defaultsTo: defaultOptions.functionCoverage,
    help: 'Collect function coverage info.',
  )
  ..addFlag(
    'branch-coverage',
    abbr: 'b',
    defaultsTo: defaultOptions.branchCoverage,
    help: 'Collect branch coverage info.',
  )
  ..addOption(
    'fail-under',
    help: 'Fail if coverage is less than the given percentage (0-100)',
  )
  ..addMultiOption('scope-output',
      defaultsTo: defaultOptions.scopeOutput,
      help: 'restrict coverage results so that only scripts that start with '
          'the provided package path are considered. Defaults to the name of '
          'the current package (including all subpackages, if this is a '
          'workspace).')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

class Flags {
  Flags(
    this.packageDir,
    this.outDir,
    this.port,
    this.testScript,
    this.functionCoverage,
    this.branchCoverage,
    this.scopeOutput,
    this.failUnder, {
    required this.rest,
  });

  final String packageDir;
  final String outDir;
  final String port;
  final String testScript;
  final bool functionCoverage;
  final bool branchCoverage;
  final List<String> scopeOutput;
  final String? failUnder;
  final List<String> rest;
}

@visibleForTesting
Future<Flags> parseArgs(
    List<String> arguments, CoverageOptions defaultOptions) async {
  final parser = _createArgParser(defaultOptions);
  final args = parser.parse(arguments);

  void printUsage() {
    print('''
Runs tests and collects coverage for a package.

By default this  script assumes it's being run from the root directory of a
package, and outputs a coverage.json and lcov.info to ./coverage/

Usage: test_with_coverage [OPTIONS...] [-- <test script OPTIONS>]

${parser.usage}
''');
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

  final packageDir = path.normalize(path.absolute(args['package'] as String));
  if (!FileSystemEntity.isDirectorySync(packageDir)) {
    fail('--package is not a valid directory.');
  }

  final pubspecPath = getPubspecPath(packageDir);
  if (!File(pubspecPath).existsSync()) {
    fail(
      "Couldn't find $pubspecPath. Make sure this command is run in a "
      'package directory, or pass --package to explicitly set the directory.',
    );
  }

  return Flags(
    packageDir,
    args.option('out') ?? path.join(packageDir, 'coverage'),
    args.option('port') ?? '0',
    args.option('test')!,
    args.flag('function-coverage'),
    args.flag('branch-coverage'),
    args.multiOption('scope-output'),
    args.option('fail-under'),
    rest: args.rest,
  );
}

Future<void> main(List<String> arguments) async {
  final defaultOptions = CoverageOptionsProvider().coverageOptions;
  final flags = await parseArgs(arguments, defaultOptions);
  final outJson = path.join(flags.outDir, 'coverage.json');
  final outLcov = path.join(flags.outDir, 'lcov.info');

  if (!FileSystemEntity.isDirectorySync(flags.outDir)) {
    await Directory(flags.outDir).create(recursive: true);
  }

  _watchExitSignal(ProcessSignal.sighup);
  _watchExitSignal(ProcessSignal.sigint);
  if (!Platform.isWindows) {
    _watchExitSignal(ProcessSignal.sigterm);
  }

  final serviceUriCompleter = Completer<Uri>();
  final testProcess = _dartRun(
    [
      if (flags.branchCoverage) '--branch-coverage',
      'run',
      '--pause-isolates-on-exit',
      '--disable-service-auth-codes',
      '--enable-vm-service=${flags.port}',
      flags.testScript,
      ...flags.rest,
    ],
    onStdout: (line) {
      if (!serviceUriCompleter.isCompleted) {
        final uri = extractVMServiceUri(line);
        if (uri != null) {
          serviceUriCompleter.complete(uri);
        }
      }
    },
    onStderr: (line) {
      if (!serviceUriCompleter.isCompleted) {
        if (line.contains('Could not start the VM service')) {
          _killSubprocessesAndExit(ProcessSignal.sigkill);
        }
      }
    },
  );
  final serviceUri = await serviceUriCompleter.future;

  final scopes = flags.scopeOutput.isEmpty
      ? getAllWorkspaceNames(flags.packageDir)
      : flags.scopeOutput;
  await collect_coverage.main([
    '--wait-paused',
    '--resume-isolates',
    '--uri=$serviceUri',
    for (final scope in scopes) '--scope-output=$scope',
    if (flags.branchCoverage) '--branch-coverage',
    if (flags.functionCoverage) '--function-coverage',
    '-o',
    outJson,
  ]);
  await testProcess;

  await format_coverage.main([
    '--lcov',
    '--check-ignore',
    '--package=${flags.packageDir}',
    '-i',
    outJson,
    '-o',
    outLcov,
    if (flags.failUnder != null) '--fail-under=${flags.failUnder}',
  ]);
  exit(0);
}
