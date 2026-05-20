// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:benchmark_harness/src/blackhole.dart';
import 'package:test/test.dart';

class SampleBenchmark extends BenchmarkBase {
  int result = 0;
  SampleBenchmark() : super('Sample');

  @override
  void run() {
    result = 42 + 58;
    blackhole(result);
  }
}

class SampleAsyncBenchmark extends AsyncBenchmarkBase {
  int result = 0;
  SampleAsyncBenchmark() : super('SampleAsync');

  @override
  Future<void> run() async {
    await Future<void>.delayed(const Duration(microseconds: 1));
    result = 100;
    blackhole(result);
  }
}

void main() {
  group('blackhole shorthand', () {
    test('executes successfully without throwing errors', () {
      expect(() => blackhole('test-string'), returnsNormally);
      expect(() => blackhole(null), returnsNormally);
      expect(() => blackhole(42), returnsNormally);
    });
  });

  group('Blackhole class consume and preventDCE', () {
    test('consume executes successfully without throwing errors', () {
      final bh = Blackhole();
      expect(() => bh.consume('test-string'), returnsNormally);
      expect(() => bh.consume(null), returnsNormally);
      expect(() => bh.consume(42), returnsNormally);
    });

    test('preventDCE executes successfully without throwing errors', () {
      expect(Blackhole.preventDCE, returnsNormally);
    });
  });

  group('Benchmark Integration', () {
    test('sync benchmark using blackhole runs and measures successfully', () {
      final benchmark = SampleBenchmark();
      final score = benchmark.measure();
      expect(score, isPositive);
      expect(benchmark.result, equals(100));
    });

    test(
      'async benchmark using blackhole runs and measures successfully',
      () async {
        final benchmark = SampleAsyncBenchmark();
        final score = await benchmark.measure();
        expect(score, isPositive);
        expect(benchmark.result, equals(100));
      },
    );
  });
}
