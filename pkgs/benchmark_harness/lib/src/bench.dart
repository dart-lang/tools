// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';

import 'compile_and_run.dart';

Future<void> bench(List<String> args) async {
  final ArgResults results;
  BenchOptions? options;

  try {
    results = _$parserForBenchOptions.parse(args);
    options = _$parseBenchOptionsResult(results);
    if (options.help) {
      print(_$parserForBenchOptions.usage);
      return;
    }

    await compileAndRun(options);
  } on FormatException catch (e) {
    print(e.message);
    print(_$parserForBenchOptions.usage);
    exitCode = 64;
    return;
  } on BenchException catch (e, stack) {
    print(e.message);
    if (options?.verbose ?? true) {
      print(e);
      print(stack);
    }
    exitCode = e.exitCode;
  }
}

class BenchOptions {
  BenchOptions({
    required this.flavor,
    required this.target,
    this.help = false,
    this.verbose = false,
  }) {
    if (flavor.isEmpty) {
      // This is the wrong exception to use, except that it's caught in the
      // program, so it makes implementation easy.
      throw const FormatException('At least one `flavor` must be provided', 64);
    }
  }

  final String target;

  final Set<RuntimeFlavor> flavor;

  final bool help;
  final bool verbose;
}

BenchOptions _$parseBenchOptionsResult(ArgResults result) => BenchOptions(
      flavor:
          result.multiOption('flavor').map(RuntimeFlavor.values.byName).toSet(),
      target: result.option('target')!,
      help: result.flag('help'),
      verbose: result.flag('verbose'),
    );

ArgParser _$populateBenchOptionsParser(ArgParser parser) => parser
  ..addMultiOption(
    'flavor',
    abbr: 'f',
    allowed: RuntimeFlavor.values.map((e) => e.name),
  )
  ..addOption('target', defaultsTo: 'benchmark/benchmark.dart')
  ..addFlag('help', defaultsTo: false, negatable: false)
  ..addFlag('verbose', defaultsTo: false, negatable: false);

final _$parserForBenchOptions = _$populateBenchOptionsParser(ArgParser());

BenchOptions parseBenchOptions(List<String> args) {
  final result = _$parserForBenchOptions.parse(args);
  return _$parseBenchOptionsResult(result);
}
