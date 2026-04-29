// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'result.dart';

/// Utilities for formatting benchmark results.
class BenchmarkReport {
  /// Formats multiple results as a table.
  static String formatTable(
    List<BenchmarkResult> results, {
    String? baselineName,
  }) {
    if (results.isEmpty) return 'No results collected.';

    final baseline = baselineName != null
        ? results.firstWhere(
            (r) => r.name == baselineName,
            orElse: () => results.first,
          )
        : results.first;

    final nameWidth = results.map((r) => r.name.length).reduce(math.max);
    final buffer = StringBuffer();

    // Header
    buffer.writeln();
    buffer.writeln(
      '  ${'Variant'.padRight(nameWidth)} | '
      '${'Median'.padLeft(12)} | '
      '${'Mean'.padLeft(12)} | '
      '${'StdDev'.padLeft(10)} | '
      '${'CV%'.padLeft(6)} | '
      '${'vs Base'.padLeft(8)}',
    );
    buffer.writeln('  ${'-' * (nameWidth + 56)}');

    for (final result in results) {
      final comparison = BenchmarkComparison(test: result, baseline: baseline);
      final ratioStr = result == baseline
          ? '-'
          : '${comparison.speedup.toStringAsFixed(2)}x';

      buffer.writeln(
        '  ${result.name.padRight(nameWidth)} | '
        '${result.median.toStringAsFixed(2).padLeft(12)} | '
        '${result.mean.toStringAsFixed(2).padLeft(12)} | '
        '${result.stdDev.toStringAsFixed(2).padLeft(10)} | '
        '${result.cv.toStringAsFixed(1).padLeft(6)} | '
        '${ratioStr.padLeft(8)}',
      );
    }
    buffer.writeln('\n  (Times in microseconds per operation)');
    return buffer.toString();
  }

  /// Returns a reliability warning if a result has high variance.
  static String? getReliabilityWarning(BenchmarkResult result) {
    if (result.cv > 20) {
      return 'Warning: ${result.name} has high variance '
          '(CV: ${result.cv.toStringAsFixed(1)}%). '
          'Results may be unreliable.';
    }
    return null;
  }
}
