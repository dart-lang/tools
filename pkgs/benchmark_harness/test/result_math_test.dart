// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/src/result.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkResult & BenchmarkComparison Math', () {
    test('BenchmarkResult throws when samples list is empty', () {
      expect(
        () => BenchmarkResult(name: 'Empty', samples: []),
        throwsArgumentError,
      );
    });

    test('BenchmarkResult median calculation on odd length', () {
      final result = BenchmarkResult(name: 'Odd', samples: [10.0, 30.0, 20.0]);
      expect(result.median, equals(20.0));
    });

    test('BenchmarkResult median calculation on even length', () {
      final result = BenchmarkResult(
        name: 'Even',
        samples: [10.0, 40.0, 30.0, 20.0],
      );
      expect(result.median, equals(25.0)); // (20 + 30) / 2 = 25
    });

    test('BenchmarkResult toString formatting matches expected pattern', () {
      final result = BenchmarkResult(
        name: 'MyVariant',
        samples: [100.0, 100.0, 100.0],
      );
      expect(result.toString(), equals('MyVariant: 100.00 us (CV: 0.0%)'));
    });

    test('BenchmarkComparison speedup and improvement ratios', () {
      final baseline = BenchmarkResult(
        name: 'Base',
        samples: [100.0, 100.0, 100.0],
      );
      final testFast = BenchmarkResult(
        name: 'Fast',
        samples: [50.0, 50.0, 50.0],
      );

      final comparison = BenchmarkComparison(
        test: testFast,
        baseline: baseline,
      );

      expect(comparison.speedup, equals(2.0));
      expect(comparison.improvement, equals(0.5)); // 50% improvement (0.5)
      expect(comparison.toString(), equals('Fast vs Base: 2.00x (+50.0%)'));
    });

    test('BenchmarkComparison handles slowdowns correctly', () {
      final baseline = BenchmarkResult(
        name: 'Base',
        samples: [100.0, 100.0, 100.0],
      );
      final testSlow = BenchmarkResult(
        name: 'Slow',
        samples: [200.0, 200.0, 200.0],
      );

      final comparison = BenchmarkComparison(
        test: testSlow,
        baseline: baseline,
      );

      expect(comparison.speedup, equals(0.5));
      expect(comparison.improvement, equals(-1.0)); // -100% regression (-1.0)
      expect(comparison.toString(), equals('Slow vs Base: 0.50x (-100.0%)'));
    });
  });
}
