// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'package:benchmark_harness/benchmark_harness.dart';

const _length = 100_000;
const _maxInt = 1 << 32 - 1;

/// Exposes the list of benchmarks for isolated CLI execution via:
/// `dart run benchmark_harness:bench --target example/modern_example.dart`
final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'List Comparison',
    variants: [
      BenchmarkVariant(
        name: 'Growable',
        run: () {
          final rand = Random();
          final list = <int>[
            ...Iterable.generate(_length, (i) => rand.nextInt(_maxInt)),
          ];
          blackhole(list);
        },
      ),
      BenchmarkVariant(
        name: 'Fixed',
        run: () {
          final rand = Random();
          final list = List<int>.generate(
            _length,
            (i) => rand.nextInt(_maxInt),
            growable: false,
          );
          blackhole(list);
        },
      ),
    ],
  ),
];

/// Enables direct file execution via `dart example/modern_example.dart`
void main() async {
  for (final benchmark in benchmarks) {
    final results = await benchmark.run();
    print(BenchmarkReport.formatTable(results));
  }
}
