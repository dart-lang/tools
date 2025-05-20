// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';

enum RuntimeFlavor {
  aot(help: 'Compile and run as a native binary.'),
  jit(
    help: 'Run as-is without compilation, '
        'using the just-in-time (JIT) runtime.',
  ),
  js(help: 'Compile to JavaScript and run on node.'),
  wasm(help: 'Compile to WebAssembly and run on node.');

  const RuntimeFlavor({required this.help});

  final String help;
}

class BenchOptions {
  BenchOptions({
    required this.flavor,
    required this.target,
    this.help = false,
    this.verbose = false,
  }) {
    if (!help && flavor.isEmpty) {
      // This is the wrong exception to use, except that it's caught in the
      // program, so it makes implementation easy.
      throw const FormatException('At least one `flavor` must be provided', 64);
    }
  }

  factory BenchOptions.fromArgs(List<String> args) {
    final result = _parserForBenchOptions.parse(args);

    if (result.rest.isNotEmpty) {
      throw FormatException('All arguments must be provided via `--` options. '
          'Not sure what to do with "${result.rest.join()}".');
    }

    return BenchOptions(
      flavor:
          result.multiOption('flavor').map(RuntimeFlavor.values.byName).toSet(),
      target: result.option('target')!,
      help: result.flag('help'),
      verbose: result.flag('verbose'),
    );
  }

  final String target;

  final Set<RuntimeFlavor> flavor;

  final bool help;

  final bool verbose;

  static String get usage => _parserForBenchOptions.usage;

  static final _parserForBenchOptions = ArgParser()
    ..addMultiOption('flavor',
        abbr: 'f',
        allowed: RuntimeFlavor.values.map((e) => e.name),
        allowedHelp: {
          for (final flavor in RuntimeFlavor.values) flavor.name: flavor.help
        })
    ..addOption('target',
        defaultsTo: 'benchmark/benchmark.dart',
        help: 'The target script to compile and run.')
    ..addFlag('help',
        defaultsTo: false,
        negatable: false,
        help: 'Print usage information and quit.',
        abbr: 'h')
    ..addFlag('verbose',
        defaultsTo: false,
        negatable: false,
        help: 'Print the full stack trace if an exception is thrown.',
        abbr: 'v');
}
