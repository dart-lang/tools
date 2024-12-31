// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coverage/src/coverage_options.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

final String testAppPath = p.join('test', 'test_files', 'test_app.dart');

const Duration timeout = Duration(seconds: 20);

Future<TestProcess> runTestApp(int openPort) => TestProcess.start(
      Platform.resolvedExecutable,
      [
        '--enable-vm-service=$openPort',
        '--pause_isolates_on_exit',
        '--branch-coverage',
        testAppPath
      ],
    );

List<Map<String, dynamic>> coverageDataFromJson(Map<String, dynamic> json) {
  expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
  expect(json, containsPair('type', 'CodeCoverage'));

  return (json['coverage'] as List).cast<Map<String, dynamic>>();
}

final _versionPattern = RegExp('([0-9]+)\\.([0-9]+)\\.([0-9]+)');

bool platformVersionCheck(int minMajor, int minMinor) {
  final match = _versionPattern.matchAsPrefix(Platform.version);
  if (match == null) return false;
  if (match.groupCount < 3) return false;
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  return major > minMajor || (major == minMajor && minor >= minMinor);
}

/// Returns a mapping of (URL: (function_name: hit_count)) from [sources].
Map<String, Map<String, int>> functionInfoFromSources(
  Map<String, List<Map<dynamic, dynamic>>> sources,
) {
  Map<int, String> getFuncNames(List list) {
    return {
      for (var i = 0; i < list.length; i += 2)
        list[i] as int: list[i + 1] as String,
    };
  }

  Map<int, int> getFuncHits(List list) {
    return {
      for (var i = 0; i < list.length; i += 2)
        list[i] as int: list[i + 1] as int,
    };
  }

  return {
    for (var entry in sources.entries)
      entry.key: entry.value.fold(
        {},
        (previousValue, element) {
          expect(element['source'], entry.key);
          final names = getFuncNames(element['funcNames'] as List);
          final hits = getFuncHits(element['funcHits'] as List);

          for (var pair in hits.entries) {
            previousValue[names[pair.key]!] =
                (previousValue[names[pair.key]!] ?? 0) + pair.value;
          }

          return previousValue;
        },
      ),
  };
}

extension ListTestExtension on List {
  Map<String, List<Map<dynamic, dynamic>>> sources() => cast<Map>().fold(
        <String, List<Map>>{},
        (Map<String, List<Map>> map, value) {
          final sourceUri = value['source'] as String;
          map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
          return map;
        },
      );
}

CollectCoverageOptions parseArgsCollectCoverage(
    List<String> arguments, CollectCoverageOptions defaultOptions) {
  final parser = ArgParser()
    ..addOption('host', abbr: 'H')
    ..addOption('port', abbr: 'p')
    ..addOption('uri', abbr: 'u')
    ..addOption('out', abbr: 'o', defaultsTo: defaultOptions.out)
    ..addOption('connect-timeout',
        abbr: 't', defaultsTo: defaultOptions.connectTimeout?.toString())
    ..addMultiOption('scope-output', defaultsTo: defaultOptions.scopeOutput)
    ..addFlag('wait-paused', abbr: 'w', defaultsTo: defaultOptions.waitPaused)
    ..addFlag('resume-isolates',
        abbr: 'r', defaultsTo: defaultOptions.resumeIsolates)
    ..addFlag('include-dart', abbr: 'd', defaultsTo: defaultOptions.includeDart)
    ..addFlag('function-coverage',
        abbr: 'f', defaultsTo: defaultOptions.functionCoverage)
    ..addFlag('branch-coverage',
        abbr: 'b', defaultsTo: defaultOptions.branchCoverage)
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);

  String serviceUri;
  if (args['uri'] == null && (args['host'] != null || args['port'] != null)) {
    final host = args['host'] ?? defaultOptions.host;
    final port = args['port'] ?? defaultOptions.port;

    serviceUri = 'http://$host:$port/';
  } else {
    serviceUri = (args['uri'] ?? defaultOptions.uri) as String;
  }

  return CollectCoverageOptions(
    uri: serviceUri,
    out: args['out'] as String,
    connectTimeout: int.tryParse(args['connect-timeout'] as String? ?? ''),
    scopeOutput: args['scope-output'] as List<String>,
    waitPaused: args['wait-paused'] as bool,
    resumeIsolates: args['resume-isolates'] as bool,
    includeDart: args['include-dart'] as bool,
    functionCoverage: args['function-coverage'] as bool,
    branchCoverage: args['branch-coverage'] as bool,
  );
}

FormatCoverageOptions parseArgsFormatCoverage(
    List<String> arguments, FormatCoverageOptions defaultOptions) {
  final parser = ArgParser()
    ..addOption('sdk-root', abbr: 's', defaultsTo: defaultOptions.sdkRoot)
    ..addOption('packages')
    ..addOption('package', defaultsTo: defaultOptions.packagePath)
    ..addOption('in', abbr: 'i', defaultsTo: defaultOptions.input)
    ..addOption('out', abbr: 'o', defaultsTo: defaultOptions.output)
    ..addMultiOption('report-on', defaultsTo: defaultOptions.reportOn)
    ..addOption('workers',
        abbr: 'j', defaultsTo: defaultOptions.workers.toString())
    ..addOption('bazel-workspace', defaultsTo: defaultOptions.bazelWorkspace)
    ..addOption('base-directory',
        abbr: 'b', defaultsTo: defaultOptions.baseDirectory)
    ..addFlag('bazel',
        defaultsTo: defaultOptions.bazel,
        help: 'use Bazel-style path resolution')
    ..addFlag('pretty-print',
        abbr: 'r', defaultsTo: defaultOptions.prettyPrint, negatable: false)
    ..addFlag('pretty-print-func',
        abbr: 'f', defaultsTo: defaultOptions.prettyPrintFunc, negatable: false)
    ..addFlag('pretty-print-branch',
        negatable: false, defaultsTo: defaultOptions.prettyPrintBranch)
    ..addFlag('lcov',
        abbr: 'l', defaultsTo: defaultOptions.lcov, negatable: false)
    ..addFlag('verbose',
        abbr: 'v', defaultsTo: defaultOptions.verbose, negatable: false)
    ..addFlag('check-ignore',
        abbr: 'c', defaultsTo: defaultOptions.checkIgnore, negatable: false)
    ..addMultiOption('ignore-files', defaultsTo: defaultOptions.ignoreFiles)
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);

  if (args['in'] == null) throw ArgumentError('Missing required argument: in');

  return FormatCoverageOptions(
    baseDirectory: args['base-directory'] as String?,
    bazel: args['bazel'] as bool,
    bazelWorkspace: args['bazel-workspace'] as String,
    checkIgnore: args['check-ignore'] as bool,
    input: args['in'] as String,
    lcov: args['lcov'] as bool,
    output: args['out'] as String,
    packagePath: args['package'] as String,
    prettyPrint: args['lcov'] as bool ? false : args['pretty-print'] as bool,
    prettyPrintFunc: args['pretty-print-func'] as bool,
    prettyPrintBranch: args['pretty-print-branch'] as bool,
    reportOn: (args['report-on'] as List<String>).isNotEmpty
        ? args['report-on'] as List<String>
        : null,
    ignoreFiles: args['ignore-files'] as List<String>,
    sdkRoot: args['sdk-root'] as String?,
    verbose: args['verbose'] as bool,
    workers: int.parse(args['workers'] as String),
  );
}

Future<TestWithCoverageOptions> parseArgsTestWithCoverage(
    List<String> arguments, TestWithCoverageOptions defaultOptions) async {
  final parser = ArgParser()
    ..addOption(
      'package',
      defaultsTo: defaultOptions.packageDir,
    )
    ..addOption(
      'package-name',
      defaultsTo: defaultOptions.packageName,
    )
    ..addOption('port', defaultsTo: defaultOptions.port)
    ..addOption(
      'out',
      defaultsTo: defaultOptions.outDir,
      abbr: 'o',
    )
    ..addOption('test', defaultsTo: defaultOptions.testScript)
    ..addFlag(
      'function-coverage',
      abbr: 'f',
      defaultsTo: defaultOptions.functionCoverage,
    )
    ..addFlag(
      'branch-coverage',
      abbr: 'b',
      defaultsTo: defaultOptions.branchCoverage,
    )
    ..addMultiOption('scope-output', defaultsTo: defaultOptions.scopeOutput)
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);

  final packageDir = p.canonicalize(args['package'] as String);
  if (!FileSystemEntity.isDirectorySync(packageDir)) {
    ArgumentError('Invalid package directory: $packageDir');
  }

  final packageName = (args['package-name'] as String?) ??
      await _packageNameFromConfig(packageDir);
  if (packageName == null) {
    ArgumentError('Could not determine package name');
  }

  return TestWithCoverageOptions(
    packageDir: packageDir,
    packageName: packageName,
    outDir: (args['out'] as String?) ?? 'coverage',
    port: args['port'] as String,
    testScript: args['test'] as String,
    functionCoverage: args['function-coverage'] as bool,
    branchCoverage: args['branch-coverage'] as bool,
    scopeOutput: args['scope-output'] as List<String>,
  );
}

Future<String?> _packageNameFromConfig(String packageDir) async {
  final config = await findPackageConfig(Directory(packageDir));
  return config?.packageOf(Uri.directory(packageDir))?.name;
}

String getPackageDir(final String package) {
  return p.canonicalize(package);
}
