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
  final allowedJitter =
      minimumMillis < 1000 ? 0 : (minimumMicros * 0.1).floor();
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
        minimumMicros: minimumMicros);
    totalIterations += iter;
  }
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

int _roundDownToMillisecond(int micros) => (micros ~/ 1000) * 1000;
