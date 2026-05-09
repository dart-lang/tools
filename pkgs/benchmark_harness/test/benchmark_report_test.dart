// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/src/report.dart';
import 'package:benchmark_harness/src/result.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkReport', () {
    test('formatTable handles empty results list', () {
      final report = BenchmarkReport.formatTable([]);
      expect(report, equals('No results collected.'));
    });

    test('formatTable formats table with baseline comparison correctly', () {
      final baseline = BenchmarkResult(
        name: 'Base',
        samples: [100.0, 100.0, 100.0],
      );
      final testResult = BenchmarkResult(
        name: 'FastVariant',
        samples: [50.0, 50.0, 50.0],
      );

      final report = BenchmarkReport.formatTable([
        baseline,
        testResult,
      ], baselineName: 'Base');

      expect(report, contains('Variant'));
      expect(report, contains('Median'));
      expect(report, contains('vs Base'));
      expect(report, contains('Base'));
      expect(report, contains('FastVariant'));
      expect(report, contains('2.00x')); // 100 / 50 = 2x speedup
      expect(report, contains('(Times in microseconds per operation)'));
    });

    test(
      'getReliabilityWarning returns null for stable, low-variance runs',
      () {
        final result = BenchmarkResult(
          name: 'StableRun',
          samples: [100.0, 100.0, 100.0],
        );
        expect(BenchmarkReport.getReliabilityWarning(result), isNull);
      },
    );

    test('getReliabilityWarning triggers on unstable warmup runs', () {
      final result = BenchmarkResult(
        name: 'UnstableRun',
        samples: [100.0, 100.0, 100.0],
        isStable: false,
      );
      final warning = BenchmarkReport.getReliabilityWarning(result);
      expect(warning, isNotNull);
      expect(warning, contains('failed to reach mathematical steady state'));
    });

    test('getReliabilityWarning triggers on high-variance runs', () {
      // Highly varying samples to push CV above 20%
      final result = BenchmarkResult(
        name: 'JitteryRun',
        samples: [10.0, 100.0, 10.0, 100.0, 10.0, 100.0],
      );

      // Verify CV is > 20% (0.2)
      expect(result.cv > 0.2, isTrue);

      final warning = BenchmarkReport.getReliabilityWarning(result);
      expect(warning, isNotNull);
      expect(warning, contains('has high variance'));
    });
  });
}
