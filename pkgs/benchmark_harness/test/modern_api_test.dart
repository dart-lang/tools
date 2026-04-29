// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:benchmark_harness/src/runner.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkResult', () {
    test('calculates statistics correctly', () {
      final result = BenchmarkResult(name: 'test', samples: [10.0, 20.0, 30.0]);

      expect(result.mean, 20.0);
      expect(result.median, 20.0);
      expect(result.stdDev, closeTo(10.0, 0.1));
      expect(result.cv, closeTo(50.0, 0.1));
    });

    test('median handles even number of samples', () {
      final result = BenchmarkResult(
        name: 'test',
        samples: [10.0, 20.0, 30.0, 40.0],
      );
      expect(result.median, 25.0);
    });
  });

  group('BenchmarkRunner', () {
    test('calibration finds iterations', () {
      final runner = BenchmarkRunner(
        'test',
        config: const RunnerConfig(targetSampleMicros: 1000),
      );
      final result = runner.run(() {
        // simulate some work
        for (var i = 0; i < 1000; i++) {}
      });

      expect(result.samples.length, greaterThanOrEqualTo(10));
    });

    test('async support', () async {
      final runner = BenchmarkRunner(
        'test',
        config: const RunnerConfig(minSamples: 5),
      );
      final result = await runner.runAsync(() async {
        await Future<void>.delayed(const Duration(microseconds: 1));
      });

      expect(result.samples.length, greaterThanOrEqualTo(5));
    });
  });

  group('Compositional API', () {
    test('Benchmark and BenchmarkVariant', () async {
      final benchmark = Benchmark(
        title: 'Comparison',
        variants: [
          BenchmarkVariant(name: 'v1', run: () => 1 + 1),
          BenchmarkVariant(name: 'v2', run: () => 2 + 2),
        ],
        config: const RunnerConfig(minSamples: 2, maxSamples: 5),
      );

      final results = await benchmark.run();
      expect(results.length, 2);
      expect(results[0].name, 'v1');
      expect(results[1].name, 'v2');
    });
  });

  group('JsonEmitter', () {
    test('outputs structured results', () {
      final emitter = JsonEmitter();
      final result = BenchmarkResult(name: 'v1', samples: [10.0, 10.0]);
      emitter.emitDetailed(result);

      final json = jsonDecode(emitter.toString());
      expect(json['v1']['median'], 10.0);
      expect(json['v1']['samples'], [10.0, 10.0]);
    });
  });
}
