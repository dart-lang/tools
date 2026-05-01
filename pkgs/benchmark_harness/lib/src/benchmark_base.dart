// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'measurement.dart';
import 'score_emitter.dart';

const int minimumMeasureDurationMillis = 2000;

class BenchmarkBase {
  final String name;
  final ScoreEmitter emitter;

  const BenchmarkBase(this.name, {this.emitter = const PrintEmitter()});

  /// The benchmark code.
  ///
  /// This function is not used, if both [warmup] and [exercise] are
  /// overwritten.
  void run() {}

  /// Runs a short version of the benchmark. By default invokes [run] once.
  void warmup() {
    run();
  }

  /// Exercises the benchmark. By default invokes [run] 10 times.
  void exercise() {
    for (var i = 0; i < 10; i++) {
      run();
    }
  }

  /// Not measured setup code executed prior to the benchmark runs.
  void setup() {}

  /// Not measured teardown code executed after the benchmark runs.
  void teardown() {}

  /// Measures the score for this benchmark by executing it enough times
  /// to reach [minimumMillis].

  /// Measures the score for this benchmark by executing it repeatedly until
  /// time minimum has been reached.
  static double measureFor(void Function() f, int minimumMillis) =>
      measureForImpl(f, minimumMillis).score;

  /// Measures the score for the benchmark and returns it.
  double measure() {
    setup();
    // Warmup for at least 100ms. Discard result.
    measureForImpl(warmup, 100);
    // Run the benchmark for at least 2000ms.
    var result = measureForImpl(exercise, minimumMeasureDurationMillis);
    teardown();
    return result.score;
  }

  /// Measures the benchmark by timing each [run] call individually for
  /// at least [minimumMillis] milliseconds.
  ///
  /// Bypasses any [exercise] override (always calls [run] directly). The
  /// reported score is per-[run], so it will be ~10x smaller than [measure]
  /// with the default [exercise]. Recommended for benchmarks where one
  /// [run] takes at least about a hundred microseconds; for faster
  /// benchmarks the per-call stopwatch overhead distorts results.
  ///
  /// **Choosing [minimumMillis]:** sample count is approximately
  /// `minimumMillis / per-run-time`. The CV estimator's own error scales
  /// roughly as `1 / sqrt(2 * (n - 1))`, so a CV computed from only a
  /// handful of samples carries large uncertainty and is not a reliable
  /// indicator of stability. Aim for at least a few dozen samples for a
  /// trustworthy CV. The default of [minimumMeasureDurationMillis] is
  /// appropriate for benchmarks where one [run] takes a few tens of
  /// milliseconds or less; for slower benchmarks pick a larger budget so
  /// enough samples are collected (e.g., a 200 ms `run` needs ~6 s for
  /// 30 samples; a 1 s `run` needs ~30 s).
  DetailedMeasurement measureDetailed({
    int minimumMillis = minimumMeasureDurationMillis,
  }) {
    setup();
    // Warmup for at least 100ms. Discard result.
    measureForImpl(warmup, 100);
    final result = measureRunsDirect(run, minimumMillis);
    teardown();
    return result;
  }

  void report() {
    emitter.emit(name, measure());
  }

  /// Like [report], but prints the per-[run] mean alongside CV%, sample
  /// count, and min via [printDetailedMeasurement]. Ignores [emitter];
  /// callers wanting a custom rendering should use [measureDetailed]
  /// directly and format the returned [DetailedMeasurement] themselves.
  ///
  /// See [measureDetailed] for guidance on selecting [minimumMillis].
  /// The budget should be chosen so enough samples are collected for the
  /// CV to be trustworthy; CV computed from few samples is not reliable.
  void reportDetailed({
    int minimumMillis = minimumMeasureDurationMillis,
  }) {
    printDetailedMeasurement(
      name,
      measureDetailed(minimumMillis: minimumMillis),
    );
  }
}
