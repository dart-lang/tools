// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'package:benchmark_harness/benchmark_harness.dart';

final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'Wrapper List creation',
    variants: [
      BenchmarkVariant(
        name: 'Growable',
        run: () {
          final rand = Random();
          final list = <int>[
            ...Iterable.generate(1000, (i) => rand.nextInt(1000)),
          ];
          blackhole(list);
        },
      ),
    ],
    config: const RunnerConfig(minSamples: 2, maxSamples: 4),
  ),
];
