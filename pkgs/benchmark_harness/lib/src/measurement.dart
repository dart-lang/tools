// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

/// Measures the score for this benchmark by executing it enough times
/// to reach [minimumMillis].
///
/// [f] will be run a minimum of 2 times.
Measurement measureForImpl(void Function() f, int minimumMillis) {
  final minimumMicros = minimumMillis * 1000;
  // If running a long measurement permit some amount of measurement jitter
  // to avoid discarding results that are almost good, but not quite there.
  final allowedJitter = minimumMillis < 1000
      ? 0
      : (minimumMicros * 0.1).floor();
  var iter = 2;
  var totalIterations = iter;
  final watch = Stopwatch()..start();
  while (true) {
    watch.reset();
    for (var i = 0; i < iter; i++) {
      f();
    }
    final elapsed = watch.elapsedMicroseconds;
    final measurement = Measurement(elapsed, iter, totalIterations);
    if (measurement.elapsedMicros >= (minimumMicros - allowedJitter)) {
      return measurement;
    }

    iter = measurement.estimateIterationsNeededToReach(
      minimumMicros: minimumMicros,
    );
    totalIterations += iter;
  }
}

/// Measures [run] by timing each call individually until total elapsed
/// time reaches [minimumMillis] milliseconds.
///
/// The returned [DetailedMeasurement] carries one timing per call. The
/// score is the per-[run] mean (in microseconds), so it will be smaller
/// than [measureForImpl] applied to a default `exercise` (which batches
/// 10 runs per iteration).
///
/// Sample count is determined entirely by the time budget. The loop
/// never extends past [minimumMillis] to chase a sample-count target.
/// A CV% computed from only a handful of samples is not statistically
/// reliable, so callers should pick [minimumMillis] so that
/// `minimumMillis / expected per-run time` produces enough samples
/// (a few dozen as a rule of thumb).
///
/// Intended for benchmarks where one [run] call clears the timer noise
/// floor (a hundred microseconds or more). Below that, stopwatch
/// overhead and timer quantization distort both score and CV.
DetailedMeasurement measureRunsDirect(
  void Function() run,
  int minimumMillis,
) {
  final minimumMicros = minimumMillis * 1000;
  final samples = <int>[];
  final watch = Stopwatch()..start();
  var lastUs = 0;
  // Loop until the time budget is met AND there are at least 2 samples,
  // since sample stddev (n-1) is undefined for a single sample. This
  // matters when one [run] takes longer than [minimumMillis].
  while (lastUs < minimumMicros || samples.length < 2) {
    run();
    final now = watch.elapsedMicroseconds;
    samples.add(now - lastUs);
    lastUs = now;
  }
  return DetailedMeasurement(samples);
}

class Measurement {
  Measurement(this.elapsedMicros, this.iterations, this.totalIterations);

  final int elapsedMicros;
  final int iterations;
  final int totalIterations;

  double get score => elapsedMicros / iterations;

  int estimateIterationsNeededToReach({required int minimumMicros}) {
    final elapsed = _roundDownToMillisecond(elapsedMicros);
    return elapsed == 0
        ? iterations * 1000
        : (iterations * math.max(minimumMicros / elapsed, 1.5)).ceil();
  }

  @override
  String toString() => '$elapsedMicros in $iterations iterations';
}

/// A measurement that retains the per-call elapsed time of every call
/// to the benchmark function, enabling derived statistics.
class DetailedMeasurement {
  DetailedMeasurement(this.samples) : assert(samples.length >= 2);

  /// Per-call elapsed time in microseconds, one entry per call.
  final List<int> samples;

  /// Smallest sample in microseconds. The fastest observed call.
  int get minMicros {
    var lo = samples[0];
    for (final v in samples) {
      if (v < lo) lo = v;
    }
    return lo;
  }

  /// Median of [samples] in microseconds. For an even sample count,
  /// this is the average of the two middle values.
  ///
  /// More robust than [meanMicros] when the distribution has a tail
  /// (e.g., occasional GC pauses) — the typical-case run time.
  double get medianMicros {
    final sorted = List<int>.from(samples)..sort();
    final n = sorted.length;
    if (n.isOdd) return sorted[n ~/ 2].toDouble();
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  /// Mean of [samples] in microseconds.
  double get meanMicros {
    var sum = 0;
    for (final v in samples) {
      sum += v;
    }
    return sum / samples.length;
  }

  /// Sample standard deviation (n-1) of [samples] in microseconds.
  double get stddevMicros {
    final m = meanMicros;
    var sq = 0.0;
    for (final v in samples) {
      final d = v - m;
      sq += d * d;
    }
    return math.sqrt(sq / (samples.length - 1));
  }

  /// Coefficient of variation (stddev / mean), expressed as a percentage.
  /// Always computable from at least two samples. Callers should decide
  /// whether the value is meaningful: it is unreliable when the per-call
  /// mean is near the timer noise floor or when very few samples were
  /// collected.
  double get coefficientOfVariation => stddevMicros / meanMicros * 100;
}

int _roundDownToMillisecond(int micros) => (micros ~/ 1000) * 1000;
