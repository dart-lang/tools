// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library benchmark_harness_test;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:test/test.dart';

void main() {
  group('benchmark_harness', () {
    test('run is called', () {
      var benchmark = MockBenchmark();
      var micros = benchmark.measure();
      expect(micros, isPositive);
      expect(benchmark.runCount, isPositive);
    });
  });
}

class MockBenchmark extends BenchmarkBase {
  int runCount = 0;

  MockBenchmark() : super('mock benchmark');

  @override
  void run() {
    runCount++;
  }
}
