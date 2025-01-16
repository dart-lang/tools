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

CoverageOptions parseArgsCollectCoverage(
    List<String> arguments, CoverageOptions defaultOptions) {
  final parser = ArgParser()
    ..addOption('out', abbr: 'o')
    ..addMultiOption('scope-output', defaultsTo: defaultOptions.scopeOutput)
    ..addFlag('function-coverage',
        abbr: 'f', defaultsTo: defaultOptions.functionCoverage)
    ..addFlag('branch-coverage',
        abbr: 'b', defaultsTo: defaultOptions.branchCoverage);

  final args = parser.parse(arguments);

  String out;
  final outPath = args['out'] as String?;
  if (outPath == null && defaultOptions.output == null) {
    out = 'stdout';
  } else {
    out = outPath ?? '${defaultOptions.output}/coverage.json';
  }

  return CoverageOptions(
    output: out,
    scopeOutput: args['scope-output'] as List<String>,
    functionCoverage: args['function-coverage'] as bool,
    branchCoverage: args['branch-coverage'] as bool,
    packagePath: defaultOptions.packagePath,
    packageName: defaultOptions.packageName,
    testScript: defaultOptions.testScript,
  );
}

CoverageOptions parseArgsFormatCoverage(
    List<String> arguments, CoverageOptions defaultOptions) {
  final parser = ArgParser()
    ..addOption('package', defaultsTo: defaultOptions.packagePath)
    ..addOption('out', abbr: 'o');

  final args = parser.parse(arguments);

  String out;
  final outPath = args['out'] as String?;
  if (outPath == null && defaultOptions.output == null) {
    out = 'stdout';
  } else {
    out = outPath ?? '${defaultOptions.output}/lcov.info';
  }

  return CoverageOptions(
    output: out,
    packagePath: args['package'] as String,
    branchCoverage: defaultOptions.branchCoverage,
    functionCoverage: defaultOptions.functionCoverage,
    packageName: defaultOptions.packageName,
    scopeOutput: defaultOptions.scopeOutput,
    testScript: defaultOptions.testScript,
  );
}

Future<CoverageOptions> parseArgsTestWithCoverage(
    List<String> arguments, CoverageOptions defaultOptions) async {
  final parser = ArgParser()
    ..addOption(
      'package',
      defaultsTo: defaultOptions.packagePath,
    )
    ..addOption(
      'package-name',
      defaultsTo: defaultOptions.packageName,
    )
    ..addOption(
      'out',
      defaultsTo: defaultOptions.output,
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
    ..addMultiOption('scope-output', defaultsTo: defaultOptions.scopeOutput);

  final args = parser.parse(arguments);

  final packageDir = p.canonicalize(args['package'] as String);
  if (!FileSystemEntity.isDirectorySync(packageDir)) {
    ArgumentError('Invalid package directory: $packageDir');
  }

  final packageName =
      args['package-name'] ?? await _packageNameFromConfig(packageDir);
  if (packageName == null) {
    ArgumentError('Could not determine package name');
  }

  return CoverageOptions(
    packagePath: packageDir,
    packageName: packageName as String,
    output: (args['out'] as String?) ?? 'coverage',
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
