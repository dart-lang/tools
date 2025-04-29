// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'hitmap.dart';

/// Calculates the coverage percentage from a hitmap.
///
/// [hitmap] is the map of file paths to hit maps.
///
/// Returns a [CoverageResult] containing the coverage percentage and line
/// counts.
CoverageResult calculateCoveragePercentage(Map<String, HitMap> hitmap) {
  var totalLines = 0;
  var coveredLines = 0;
  for (final entry in hitmap.entries) {
    final lineHits = entry.value.lineHits;
    final branchHits = entry.value.branchHits;
    totalLines += lineHits.length;
    if (branchHits != null) {
      totalLines += branchHits.length;
      coveredLines += branchHits.values.where((v) => v > 0).length;
    }
    coveredLines += lineHits.values.where((v) => v > 0).length;
  }
  final coveragePercentage =
      totalLines > 0 ? coveredLines * 100 / totalLines : 0.0;

  return CoverageResult(
    percentage: coveragePercentage,
    coveredLines: coveredLines,
    totalLines: totalLines,
  );
}

/// The result of a coverage calculation.
class CoverageResult {
  /// Creates a new [CoverageResult].
  const CoverageResult({
    required this.percentage,
    required this.coveredLines,
    required this.totalLines,
  });

  /// The coverage percentage.
  final double percentage;

  /// The number of covered lines.
  final int coveredLines;

  /// The total number of lines.
  final int totalLines;
}
