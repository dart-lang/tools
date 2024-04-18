// Copyright 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/perf_benchmark_harness.dart';
import 'package:test/test.dart';

class PerfBenchmark extends PerfBenchmarkBase {
  PerfBenchmark(super.name);
  int runCount = 0;

  @override
  void run() {
    runCount++;
    for (final i in List.filled(1000, 7)) {
      runCount += i - i;
    }
  }
}

void main() {
  test('run is called', () async {
    final benchmark = PerfBenchmark('ForLoop');
    await benchmark.reportPerf();
  });
}
