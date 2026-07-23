// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/src/kbssd_math.dart';
import 'package:test/test.dart';

void main() {
  group('KBSSD Math: calculateMAD', () {
    test('handles empty data', () {
      expect(calculateMAD([], 0.0), equals(0.0));
    });

    test('handles single element data', () {
      expect(calculateMAD([5.0], 5.0), equals(0.0));
    });

    test('calculates MAD correctly on odd length list', () {
      // Data: 1, 2, 3. Median is 2.
      // Absolute deviations: |1-2|=1, |2-2|=0, |3-2|=1.
      // Sorted absolute deviations: 0, 1, 1.
      // Median of absolute deviations: 1.
      expect(calculateMAD([1.0, 2.0, 3.0], 2.0), equals(1.0));
    });

    test('calculates MAD correctly on even length list', () {
      // Data: 1, 2, 3, 4. Median is 2.5.
      // Absolute deviations:
      // |1-2.5|=1.5, |2-2.5|=0.5, |3-2.5|=0.5, |4-2.5|=1.5.
      // Sorted absolute deviations: 0.5, 0.5, 1.5, 1.5.
      // Median of absolute deviations: (0.5 + 1.5) / 2.0 = 1.0.
      expect(calculateMAD([1.0, 2.0, 3.0, 4.0], 2.5), equals(1.0));
    });

    test('calculates MAD correctly with unsorted deviations', () {
      // Data: 1, 2, 9. Median is 2.
      // Absolute deviations: |1-2|=1, |2-2|=0, |9-2|=7.
      // Sorted absolute deviations: 0, 1, 7.
      // Median of absolute deviations: 1.
      expect(calculateMAD([1.0, 2.0, 9.0], 2.0), equals(1.0));
    });
  });

  group('KBSSD Math: trimWindow', () {
    test('handles empty window', () {
      expect(trimWindow([], 0.10), isEmpty);
    });

    test('handles zero trim percentage', () {
      final window = [3.0, 1.0, 2.0];
      expect(trimWindow(window, 0.0), equals([1.0, 2.0, 3.0]));
    });

    test('handles trim count exceeding window size', () {
      // With 3 elements and 40% trim:
      // trimCount = round(3 * 0.4) = round(1.2) = 1.
      // trimCount * 2 = 2 < 3. So it trims 1 from each side.
      expect(trimWindow([3.0, 1.0, 2.0], 0.40), equals([2.0]));

      // With 3 elements and 50% trim: trimCount = round(3 * 0.5) = 2.
      // trimCount * 2 = 4 >= 3. Should return sorted window without trimming.
      expect(trimWindow([3.0, 1.0, 2.0], 0.50), equals([1.0, 2.0, 3.0]));
    });

    test('trims extremes correctly', () {
      final window = [
        10.0,
        1.0,
        5.0,
        4.0,
        6.0,
        3.0,
        7.0,
        2.0,
        8.0,
        9.0,
      ]; // 10 elements
      // trimPercentage = 0.10 => trimCount = round(10 * 0.10) = 1.
      // Sorted: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
      // Trimmed: 2, 3, 4, 5, 6, 7, 8, 9
      expect(
        trimWindow(window, 0.10),
        equals([2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]),
      );
    });
  });

  group('KBSSD Math: estimateSigma', () {
    test('handles empty buffer', () {
      expect(estimateSigma([]), equals(1.0));
    });

    test('handles single element buffer', () {
      expect(estimateSigma([5.0]), equals(0.0));
    });

    test('handles uniform values', () {
      expect(estimateSigma([5.0, 5.0, 5.0]), equals(0.0));
    });

    test('calculates population standard deviation correctly', () {
      // Data: 2, 4, 4, 4, 5, 5, 7, 9
      // Mean = (2+4+4+4+5+5+7+9) / 8 = 40 / 8 = 5.0
      // Sum of squared deviations:
      // (2-5)^2 = 9
      // (4-5)^2 * 3 = 3
      // (5-5)^2 * 2 = 0
      // (7-5)^2 = 4
      // (9-5)^2 = 16
      // Sum = 9 + 3 + 0 + 4 + 16 = 32.0
      // Population variance = 32.0 / 8 = 4.0
      // Population standard deviation = sqrt(4.0) = 2.0
      expect(
        estimateSigma([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]),
        equals(2.0),
      );
    });
  });

  group('KBSSD Math: calculateMMD', () {
    test('handles empty lists', () {
      expect(calculateMMD([], [], 1.0), equals(0.0));
    });

    test('identifies identical distributions', () {
      final X = [1.0, 2.0, 3.0, 4.0, 5.0];
      final Y = [1.0, 2.0, 3.0, 4.0, 5.0];
      // MMD of identical distributions should be close to 0.0
      expect(calculateMMD(X, Y, 2.0), closeTo(0.0, 1e-9));
    });

    test('computes positive MMD for distinct distributions', () {
      final X = [1.0, 2.0, 3.0];
      final Y = [10.0, 11.0, 12.0];
      expect(calculateMMD(X, Y, 1.0), greaterThan(0.0));
    });
  });

  group('KBSSD Math: checkSEM', () {
    test('handles empty window', () {
      expect(checkSEM([]), isFalse);
    });

    test('handles mean of 0.0', () {
      expect(checkSEM([0.0, 0.0, 0.0]), isTrue);
    });

    test('returns false for high variance unstable windows', () {
      // Highly fluctuating window
      expect(checkSEM([1.0, 10.0, 100.0, 1000.0]), isFalse);
    });

    test('returns true for stable ultra-low variance windows', () {
      // Stable window around 100.0
      final window = [
        100.0,
        100.1,
        99.9,
        100.0,
        100.0,
        99.9,
        100.1,
        100.0,
        100.0,
        100.0,
      ];
      expect(checkSEM(window), isTrue);
    });
  });
}
