// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'package:benchmark_harness/benchmark_harness.dart';

const _length = 100_000;
const _maxInt = 1 << 32 - 1;

final _rand = Random();

List<int> _randomList() =>
    List.generate(_length, (i) => _rand.nextInt(_maxInt));

final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'List Comparison',
    variants: [
      BenchmarkVariant(
        name: 'ForIn',
        run: () {
          var count = 0;
          for (var item in _randomList()) {
            count += item;
          }
          return count;
        },
      ),
      BenchmarkVariant(
        name: 'for i in',
        run: () {
          var count = 0;
          final list = _randomList();
          for (var i = 0; i < list.length; i++) {
            count += list[i];
          }
          return count;
        },
      ),
      BenchmarkVariant(
        name: 'forEach',
        run: () {
          var count = 0;
          // ignore: avoid_function_literals_in_foreach_calls
          _randomList().forEach((item) => count += item);
          return count;
        },
      ),
      BenchmarkVariant(
        name: 'fold',
        run: () => _randomList().fold(0, (a, b) => a + b),
      ),
      BenchmarkVariant(
        name: 'reduce',
        run: () => _randomList().reduce((a, b) => a + b),
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
