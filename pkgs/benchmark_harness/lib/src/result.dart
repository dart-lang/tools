// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stats/stats.dart';

/// The result of running a benchmark variant.
///
/// Contains the raw [samples] (time per operation in microseconds) and
/// provides statistical analysis via [stats] and [confidenceInterval].
class BenchmarkResult {
  /// The name of the benchmark variant.
  final String name;

  /// The raw samples collected, where each value is microseconds per operation.
  final List<double> samples;

  /// Statistical analysis of the samples.
  late final Stats stats;

  /// The 95% confidence interval for the mean.
  late final ConfidenceInterval confidenceInterval;

  BenchmarkResult({required this.name, required this.samples}) {
    stats = Stats.fromData(samples);
    confidenceInterval = ConfidenceInterval.calculate(
      stats,
      ConfidenceLevel.percent95,
    );
  }

  /// The median time per operation in microseconds.
  double get median {
    if (samples.isEmpty) return 0;
    final sorted = List<double>.from(samples)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// The mean time per operation in microseconds.
  double get mean => stats.mean;

  /// The standard deviation in microseconds.
  double get stdDev => stats.sampleValues.standardDeviation;

  /// The coefficient of variation (CV%) as a percentage.
  double get cv => (stdDev / mean) * 100;

  @override
  String toString() {
    final m = median.toStringAsFixed(2);
    final c = cv.toStringAsFixed(1);
    return '$name: $m us (CV: $c%)';
  }
}

/// A comparison between two benchmark results.
class BenchmarkComparison {
  final BenchmarkResult test;
  final BenchmarkResult baseline;

  BenchmarkComparison({required this.test, required this.baseline});

  /// How much faster the test result is compared to the baseline.
  double get speedup => baseline.median / test.median;

  /// The percentage improvement (negative for regressions).
  double get improvement {
    return ((baseline.median - test.median) / baseline.median) * 100;
  }

  @override
  String toString() {
    final sign = improvement >= 0 ? '+' : '';
    final s = speedup.toStringAsFixed(2);
    final i = improvement.toStringAsFixed(1);
    return '${test.name} vs ${baseline.name}: ${s}x ($sign$i%)';
  }
}
