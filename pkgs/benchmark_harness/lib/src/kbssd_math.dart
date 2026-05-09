// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Mathematical and statistical algorithms for Kernel-Based Steady-State
/// Detection (KBSSD).
///
/// KBSSD combines sliding window comparisons with kernel-based distance
/// metrics to determine if a noisy time series (e.g., execution times in
/// virtualization or CI environments) has converged to a steady state.
///
/// ### References
///
/// - **Maximum Mean Discrepancy (MMD)** formulation is based on:
///   Gretton, A., Borgwardt, K. M., Rasch, M. J., Schölkopf, B., & Smola, A.
///   (2012). *A Kernel Two-Sample Test*. Journal of Machine Learning Research
///   (JMLR), 13(25), 723−773.
///
/// - **Kelly's Steady-State Detection (KSSD)** concepts (random walks with
///   drift) are adapted from:
///   Kelly, J. D. (1998). *A New Method for Automated Steady-State
///   Detection*. Industrial & Engineering Chemistry Research, 37(11),
///   4299–4311.
library;

import 'dart:math' as math;

/// Calculates the Median Absolute Deviation (MAD) of a sorted list of [data]
/// relative to its [median].
double calculateMAD(List<double> data, double median) {
  if (data.isEmpty) return 0.0;
  final absoluteDeviations = data.map((x) => (x - median).abs()).toList();
  absoluteDeviations.sort();
  final mid = absoluteDeviations.length ~/ 2;
  if (absoluteDeviations.length.isOdd) {
    return absoluteDeviations[mid];
  }
  return (absoluteDeviations[mid - 1] + absoluteDeviations[mid]) / 2.0;
}

/// Trims extreme values (both top and bottom) from a sliding [window]
/// based on [trimPercentage].
List<double> trimWindow(List<double> window, double trimPercentage) {
  final sorted = List<double>.from(window)..sort();
  final trimCount = (window.length * trimPercentage).round();
  if (trimCount * 2 >= window.length) return sorted;
  return sorted.sublist(trimCount, window.length - trimCount);
}

/// Estimates the standard deviation (sigma) of values in [buffer].
double estimateSigma(List<double> buffer) {
  if (buffer.isEmpty) return 1.0;
  final mean = buffer.reduce((a, b) => a + b) / buffer.length;
  final variance =
      buffer.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
      buffer.length;
  return math.sqrt(variance);
}

/// Calculates the Maximum Mean Discrepancy (MMD) between two trimmed windows
/// [X] and [Y] using [sigma] as the Gaussian kernel scale parameter.
double calculateMMD(List<double> X, List<double> Y, double sigma) {
  final n = X.length;
  if (n == 0) return 0.0;
  final s2 = 2.0 * math.max(sigma * sigma, 1e-9);

  var kXX = 0.0;
  var kYY = 0.0;
  var kXY = 0.0;

  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      kXX += math.exp(-math.pow(X[i] - X[j], 2) / s2);
      kYY += math.exp(-math.pow(Y[i] - Y[j], 2) / s2);
      kXY += math.exp(-math.pow(X[i] - Y[j], 2) / s2);
    }
  }

  final mmdSquared = (kXX / (n * n)) - (2.0 * kXY / (n * n)) + (kYY / (n * n));
  return math.sqrt(math.max(0.0, mmdSquared));
}

/// Evaluates whether the Standard Error of the Mean (SEM) is within 3% of the
/// mean of the [window], representing stability.
bool checkSEM(List<double> window) {
  if (window.isEmpty) return false;
  final mean = window.reduce((a, b) => a + b) / window.length;
  if (mean == 0.0) return true;
  final variance =
      window.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
      window.length;
  final stdDev = math.sqrt(variance);
  final sem = stdDev / math.sqrt(window.length);
  final ciWidth = 1.96 * sem;
  return ciWidth <= 0.03 * mean;
}
