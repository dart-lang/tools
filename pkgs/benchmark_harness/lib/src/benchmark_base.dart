// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of benchmark_harness;

const int _minimumMeasureDurationMillis = 2000;

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
  static _Measurement _measureForImpl(void Function() f, int minimumMillis) {
    final minimumMicros = minimumMillis * 1000;
    // If running a long measurement permit some amount of measurment jitter
    // to avoid discarding results that are almost good, but not quite there.
    final allowedJitter =
        minimumMillis < 1000 ? 0 : (minimumMicros * 0.1).floor();
    var iter = 2;
    final watch = Stopwatch()..start();
    while (true) {
      watch.reset();
      for (var i = 0; i < iter; i++) {
        f();
      }
      final elapsed = watch.elapsedMicroseconds;
      final measurement = _Measurement(elapsed, iter);
      if (measurement.elapsedMicros >= (minimumMicros - allowedJitter)) {
        return measurement;
      }

      iter = measurement.estimateIterationsNeededToReach(
          minimumMicros: minimumMicros);
    }
  }

  /// Measures the score for this benchmark by executing it repeatedly until
  /// time minimum has been reached.
  static double measureFor(void Function() f, int minimumMillis) =>
      _measureForImpl(f, minimumMillis).score;

  /// Measures the score for the benchmark and returns it.
  double measure() {
    setup();
    // Warmup for at least 100ms. Discard result.
    _measureForImpl(warmup, 100);
    // Run the benchmark for at least 2000ms.
    var result = _measureForImpl(exercise, _minimumMeasureDurationMillis);
    teardown();
    return result.score;
  }

  void report() {
    emitter.emit(name, measure());
  }
}

class _Measurement {
  final int elapsedMicros;
  final int iterations;

  _Measurement(this.elapsedMicros, this.iterations);

  double get score => elapsedMicros / iterations;

  int estimateIterationsNeededToReach({required int minimumMicros}) {
    final elapsed = roundDownToMillisecond(elapsedMicros);
    return elapsed == 0
        ? iterations * 1000
        : (iterations * math.max(minimumMicros / elapsed, 1.5)).ceil();
  }

  static int roundDownToMillisecond(int micros) => (micros ~/ 1000) * 1000;

  @override
  String toString() => '$elapsedMicros in $iterations iterations';
}
