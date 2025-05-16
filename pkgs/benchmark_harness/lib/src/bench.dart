// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';

enum RuntimeFlavor { aot, jit, js, wasm }

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

  factory BenchOptions.fromArgs(List<String> args) {
    final result = _parserForBenchOptions.parse(args);

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
    ..addMultiOption(
      'flavors',
      abbr: 'f',
      allowed: RuntimeFlavor.values.map((e) => e.name),
    )
    ..addOption('target', defaultsTo: 'benchmark/benchmark.dart')
    ..addFlag('help', defaultsTo: false, negatable: false)
    ..addFlag('verbose', defaultsTo: false, negatable: false);
}
