// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:test/test.dart';

void main() {
  group('DetailedMeasurement', () {
    test('mean is the arithmetic mean of samples', () {
      final m = _withSamples([100, 200, 300, 400, 500]);
      expect(m.meanMicros, 300);
    });

    test('min is the smallest sample', () {
      final m = _withSamples([300, 100, 200, 400]);
      expect(m.minMicros, 100);
    });

    test('median picks the middle value for odd counts', () {
      final m = _withSamples([300, 100, 200, 400, 50]);
      expect(m.medianMicros, 200);
    });

    test('median averages the two middle values for even counts', () {
      final m = _withSamples([10, 30, 20, 40]);
      expect(m.medianMicros, 25);
    });

    test('stddev uses Bessel correction (n-1)', () {
      // Hand-computed: samples [2,4,4,4,5,5,7,9] have mean 5,
      // sum of squared deviations = 32, variance = 32/7, stddev ~= 2.138.
      final m = _withSamples([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(m.stddevMicros, closeTo(2.138, 0.01));
    });

    test('coefficient of variation is stddev/mean*100', () {
      final m = _withSamples(List.generate(50, (i) => 1000 + (i % 5) * 10));
      final expected = m.stddevMicros / m.meanMicros * 100;
      expect(m.coefficientOfVariation, closeTo(expected, 1e-9));
    });

    test('coefficientOfVariation computes from any 2+ samples', () {
      // Math is honest regardless of how many samples there are; gating
      // is a display-level concern handled by callers.
      final m = _withSamples([10, 20, 30]);
      expect(m.coefficientOfVariation, isNonNegative);
    });
  });

  group('measureRunsDirect', () {
    test('records one sample per call and stops at the time budget', () {
      var calls = 0;
      final stopwatch = Stopwatch()..start();
      final m = measureRunsDirect(() => calls++, 50);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
      expect(m.samples, isNotEmpty);
      expect(m.samples.length, calls);
    });

    test('produces a non-empty samples list', () {
      final m = measureRunsDirect(() {}, 20);
      expect(m.samples, isNotEmpty);
    });

    test('returns at least 2 samples even when run > minimumMillis', () {
      // Each call sleep-busy-waits ~30 ms; budget is 10 ms. Without the
      // 2-sample floor this would return 1 sample and the stddev would
      // be undefined.
      final m = measureRunsDirect(() {
        final sw = Stopwatch()..start();
        while (sw.elapsedMilliseconds < 30) {}
      }, 10);
      expect(m.samples.length, greaterThanOrEqualTo(2));
    });
  });
}

DetailedMeasurement _withSamples(List<int> samples) =>
    DetailedMeasurement(samples);
