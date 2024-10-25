// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'benchmark_base.dart';
import 'score_emitter.dart';

class PerfBenchmarkBase extends BenchmarkBase {
  PerfBenchmarkBase(super.name, {super.emitter = const PrintEmitter()});

  Future<double> measurePerf() async {
    return super.measure();
  }

  Future<void> reportPerf() async {
    super.report();
  }
}
