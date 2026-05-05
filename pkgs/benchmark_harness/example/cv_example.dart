// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:benchmark_harness/benchmark_harness.dart';

/// A benchmark whose `run()` takes ~5 ms, well above the timer noise floor.
/// Demonstrates [BenchmarkBase.reportDetailed] surfacing CV% and the
/// number of samples that fed it.
class SlowSineSum extends BenchmarkBase {
  const SlowSineSum() : super('SlowSineSum');

  @override
  void run() {
    var x = 0.0;
    for (var i = 0; i < 200000; i++) {
      x += math.sin(i.toDouble());
    }
    if (x.isNaN) print('unreachable');
  }
}

void main() {
  // Baseline (per-exercise).
  const SlowSineSum().report();
  // Per-run, with detailed statistics.
  const SlowSineSum().reportDetailed();
}
