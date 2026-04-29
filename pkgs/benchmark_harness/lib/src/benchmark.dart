// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'result.dart';
import 'runner.dart';
import 'score_emitter.dart';

/// A variant of a task to be measured.
class BenchmarkVariant {
  /// A descriptive label for this variant.
  final String name;

  /// The code to execute.
  final dynamic Function() run;

  BenchmarkVariant({required this.name, required this.run});

  /// Whether this variant is asynchronous.
  bool get isAsync => run is Future<void> Function();
}

/// Orchestrates the measurement of one or more [BenchmarkVariant]s.
class Benchmark {
  /// The title of the benchmark suite.
  final String title;

  /// The variants to compare.
  final List<BenchmarkVariant> variants;

  /// The configuration for the benchmarking engine.
  final RunnerConfig config;

  Benchmark({
    required this.title,
    required this.variants,
    this.config = const RunnerConfig(),
  }) : assert(variants.isNotEmpty, 'At least one variant must be provided');

  /// Runs all variants and returns their results.
  Future<List<BenchmarkResult>> run() async {
    final results = <BenchmarkResult>[];
    for (final variant in variants) {
      final runner = BenchmarkRunner(variant.name, config: config);
      if (variant.isAsync) {
        results.add(
          await runner.runAsync(variant.run as Future<void> Function()),
        );
      } else {
        results.add(runner.run(variant.run as void Function()));
      }
    }
    return results;
  }

  /// Runs all variants and reports results using the provided [emitter].
  Future<void> report({ScoreEmitter emitter = const PrintEmitter()}) async {
    final results = await run();
    for (final result in results) {
      if (emitter is DetailedScoreEmitter) {
        emitter.emitDetailed(result);
      } else {
        emitter.emit(result.name, result.median);
      }
    }
  }
}
