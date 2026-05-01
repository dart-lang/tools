// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'result.dart';

/// Configuration for the [BenchmarkRunner].
class RunnerConfig {
  /// The target duration for a single sample in microseconds.
  ///
  /// Default is 10,000 us (10 ms).
  final int targetSampleMicros;

  /// The minimum number of samples to collect.
  final int minSamples;

  /// The maximum number of samples to collect if variance is high.
  final int maxSamples;

  /// The maximum total time to spend on a single variant in microseconds.
  final int maxTotalMicros;

  /// The target relative margin of error (as a ratio of the mean).
  ///
  /// If the 95% confidence interval width / mean is greater than this,
  /// the runner will continue taking samples up to [maxSamples].
  final double targetRelativeError;

  const RunnerConfig({
    this.targetSampleMicros = 10000,
    this.minSamples = 10,
    this.maxSamples = 30,
    this.maxTotalMicros = 5000000, // 5 seconds
    this.targetRelativeError = 0.05, // 5%
  });
}

/// A runner that performs adaptive benchmarking of a function.
class BenchmarkRunner {
  final String name;
  final RunnerConfig config;

  BenchmarkRunner(this.name, {this.config = const RunnerConfig()});

  /// Runs the [benchmark] function and returns a [BenchmarkResult].
  BenchmarkResult run(void Function() benchmark) {
    // 1. Calibrate: find iterations per sample
    var iterations = _calibrate(benchmark);

    // 2. Warmup: run for a bit to stabilize
    _warmup(benchmark, iterations);

    // 3. Sampling: collect data
    final samples = <double>[];
    final totalWatch = Stopwatch()..start();

    while (samples.length < config.maxSamples) {
      final sampleMicros = _measure(benchmark, iterations);
      samples.add(sampleMicros / iterations);

      if (samples.length >= config.minSamples) {
        if (_isStable(samples) ||
            totalWatch.elapsedMicroseconds > config.maxTotalMicros) {
          break;
        }
      }
    }

    return BenchmarkResult(name: name, samples: samples);
  }

  /// Runs the [benchmark] async function and returns a [BenchmarkResult].
  Future<BenchmarkResult> runAsync(Future<void> Function() benchmark) async {
    // Similar logic but async
    var iterations = await _calibrateAsync(benchmark);
    await _warmupAsync(benchmark, iterations);

    final samples = <double>[];
    final totalWatch = Stopwatch()..start();

    while (samples.length < config.maxSamples) {
      final sampleMicros = await _measureAsync(benchmark, iterations);
      samples.add(sampleMicros / iterations);

      if (samples.length >= config.minSamples) {
        if (_isStable(samples) ||
            totalWatch.elapsedMicroseconds > config.maxTotalMicros) {
          break;
        }
      }
    }

    return BenchmarkResult(name: name, samples: samples);
  }

  int _calibrate(void Function() f) {
    var iterations = 1;
    while (true) {
      final elapsed = _measure(f, iterations);
      if (elapsed >= config.targetSampleMicros ~/ 2) {
        // Estimate iterations needed to reach target
        return (iterations * (config.targetSampleMicros / elapsed)).ceil();
      }
      iterations *= 2;
      if (iterations > 1000000) return iterations; // Cap
    }
  }

  Future<int> _calibrateAsync(Future<void> Function() f) async {
    var iterations = 1;
    while (true) {
      final elapsed = await _measureAsync(f, iterations);
      if (elapsed >= config.targetSampleMicros ~/ 2) {
        return (iterations * (config.targetSampleMicros / elapsed)).ceil();
      }
      iterations *= 2;
      if (iterations > 100000) return iterations;
    }
  }

  void _warmup(void Function() f, int iterations) {
    // Warmup for at least 100ms or 5 samples worth
    final warmupTarget = math.max(100000, iterations * 5);
    final sw = Stopwatch()..start();
    while (sw.elapsedMicroseconds < warmupTarget) {
      for (var i = 0; i < iterations; i++) {
        f();
      }
    }
  }

  Future<void> _warmupAsync(Future<void> Function() f, int iterations) async {
    final warmupTarget = math.max(100000, iterations * 5);
    final sw = Stopwatch()..start();
    while (sw.elapsedMicroseconds < warmupTarget) {
      for (var i = 0; i < iterations; i++) {
        await f();
      }
    }
  }

  int _measure(void Function() f, int iterations) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      f();
    }
    return sw.elapsedMicroseconds;
  }

  Future<int> _measureAsync(Future<void> Function() f, int iterations) async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await f();
    }
    return sw.elapsedMicroseconds;
  }

  bool _isStable(List<double> samples) {
    final result = BenchmarkResult(name: 'tmp', samples: samples);
    // Relative error check: (confidence interval width) / mean
    final width = result.confidenceInterval.marginOfError * 2;
    return (width / result.mean) <= config.targetRelativeError;
  }
}
