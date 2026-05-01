// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'runner.dart';
import 'score_emitter.dart';

class AsyncBenchmarkBase {
  final String name;
  final ScoreEmitter emitter;

  /// Empty constructor.
  const AsyncBenchmarkBase(this.name, {this.emitter = const PrintEmitter()});

  /// The benchmark code.
  ///
  /// This function is not used, if both [warmup] and [exercise] are
  /// overwritten.
  Future<void> run() async {}

  /// Runs a short version of the benchmark. By default invokes [run] once.
  Future<void> warmup() async {
    await run();
  }

  /// Exercises the benchmark. By default invokes [run] once.
  Future<void> exercise() async {
    await run();
  }

  /// Not measured setup code executed prior to the benchmark runs.
  Future<void> setup() async {}

  /// Not measures teardown code executed after the benchmark runs.
  Future<void> teardown() async {}

  /// Measures the score for this benchmark by executing it repeatedly until
  /// time minimum has been reached.
  static Future<double> measureFor(
    Future<void> Function() f,
    int minimumMillis,
  ) async {
    final runner = BenchmarkRunner(
      'measureFor',
      config: RunnerConfig(maxTotalMicros: minimumMillis * 1000),
    );
    final result = await runner.runAsync(f);
    return result.median;
  }

  /// Measures the score for the benchmark and returns it.
  Future<double> measure() async {
    await setup();
    try {
      final runner = BenchmarkRunner(name);
      final result = await runner.runAsync(exercise);
      return result.median;
    } finally {
      await teardown();
    }
  }

  /// Run the benchmark and report results on the [emitter].
  Future<void> report() async {
    emitter.emit(name, await measure());
  }
}
