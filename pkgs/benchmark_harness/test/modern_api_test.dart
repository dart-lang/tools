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
      expect(result.cv, closeTo(0.5, 0.001));
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

      expect(result.samples, hasLength(greaterThanOrEqualTo(10)));
    });

    test('custom logger receives warnings', () {
      final warnings = <String>[];
      final runner = BenchmarkRunner(
        'logger-test',
        config: RunnerConfig(targetSampleMicros: 1000, logger: warnings.add),
      );
      runner.run(() {});

      expect(warnings, isNotEmpty);
      expect(
        warnings.first,
        contains(
          'Warning: Single invocation of "logger-test" takes under 1 '
          'millisecond',
        ),
      );
    });

    test('async support', () async {
      final runner = BenchmarkRunner(
        'test',
        config: const RunnerConfig(minSamples: 5),
      );
      final result = await runner.runAsync(() async {
        await Future<void>.delayed(const Duration(microseconds: 1));
      });

      expect(result.samples, hasLength(greaterThanOrEqualTo(5)));
    });

    test('async support with returning values', () async {
      final runner = BenchmarkRunner(
        'test-non-void',
        config: const RunnerConfig(minSamples: 3),
      );
      final result = await runner.runAsync(() async {
        await Future<void>.delayed(const Duration(microseconds: 1));
        return 42;
      });

      expect(result.samples, hasLength(greaterThanOrEqualTo(3)));
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
      expect(results, hasLength(2));
      expect(results[0].name, 'v1');
      expect(results[1].name, 'v2');
    });

    test('async variant returning value in Compositional API', () async {
      final benchmark = Benchmark(
        title: 'Async Non-Void',
        variants: [
          BenchmarkVariant(
            name: 'async-int',
            run: () async {
              await Future<void>.delayed(const Duration(microseconds: 1));
              return 100;
            },
          ),
        ],
        config: const RunnerConfig(minSamples: 2, maxSamples: 4),
      );

      final results = await benchmark.run();
      expect(results, hasLength(1));
      expect(results[0].name, 'async-int');
    });

    test('calls setup and teardown in correct sequence', () async {
      final events = <String>[];
      final benchmark = Benchmark(
        title: 'Sequence test',
        variants: [
          BenchmarkVariant(
            name: 'v1',
            setup: () {
              events.add('setup');
            },
            run: () {
              events.add('run');
            },
            teardown: () {
              events.add('teardown');
            },
          ),
        ],
        config: const RunnerConfig(minSamples: 2, maxSamples: 4),
      );

      await benchmark.run();
      // The runner will execute 'run' multiple times (cold buffer & loops),
      // but 'setup' and 'teardown' should execute exactly once around the
      // variant's measurements.
      expect(events.first, 'setup');
      expect(events.last, 'teardown');
      expect(events.where((e) => e == 'setup'), hasLength(1));
      expect(events.where((e) => e == 'teardown'), hasLength(1));
      expect(
        events.where((e) => e == 'run'),
        hasLength(greaterThanOrEqualTo(1)),
      );
    });
  });

  group('JsonEmitter', () {
    test('outputs structured results conformant to standard schema', () {
      final emitter = JsonEmitter();
      final result = BenchmarkResult(name: 'v1', samples: [10.0, 10.0]);
      emitter.emitDetailed(result);

      final json = jsonDecode(emitter.toString()) as Map<String, dynamic>;
      final v1 = json['v1'] as Map<String, dynamic>;
      expect(v1, containsPair('name', 'v1'));
      expect(v1, containsPair('variant', 'v1'));
      expect(v1, containsPair('platform', 'jit'));
      expect(v1['timestamp'], isNotNull);

      final env = v1['environment'] as Map<String, dynamic>;
      expect(env, containsPair('os', 'unknown'));
      expect(env, containsPair('dart_sdk_version', 'unknown'));

      final metrics = v1['metrics'] as Map<String, dynamic>;
      expect(metrics, containsPair('samples_count', 2));
      expect(metrics, containsPair('median_us', 10.0));
      expect(metrics, containsPair('cv', 0.0));
      expect(metrics, containsPair('isStable', true));

      final raw = v1['raw_samples_us'] as List;
      expect(raw, [10.0, 10.0]);
    });
  });

  group('Operational Guidelines & Calibration Guards', () {
    test(
      'throws CalibrationException on extremely slow runtimes (> 200ms)',
      () {
        final runner = BenchmarkRunner('slow-bench');
        expect(
          () => runner.run(() {
            final sw = Stopwatch()..start();
            while (sw.elapsedMilliseconds < 250) {}
          }),
          throwsA(isA<CalibrationException>()),
        );
      },
    );

    test('bypasses safety abort when forceRun is enabled', () {
      final runner = BenchmarkRunner(
        'fast-bench',
        config: const RunnerConfig(
          forceRun: true,
          minSamples: 2,
          maxSamples: 4,
        ),
      );
      final result = runner.run(() {});
      expect(result.isStable, isFalse); // Will not converge but runs
    });
  });

  group('RunnerConfig', () {
    test('enforces mathematical assertions in constructor', () {
      expect(() => RunnerConfig(maxSamples: 3), throwsA(isA<AssertionError>()));
      expect(() => RunnerConfig(windowSize: 1), throwsA(isA<AssertionError>()));
      expect(
        () => RunnerConfig(stabilityRequired: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RunnerConfig(stabilityRequired: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(RunnerConfig.new, returnsNormally);
    });
  });

  group('blackhole', () {
    test('executes successfully without throwing NoSuchMethodError', () {
      expect(() => blackhole('test-string'), returnsNormally);
      expect(() => blackhole(null), returnsNormally);
      expect(() => blackhole(42), returnsNormally);
    });

    test(
      'implicit blackhole natively sinks return values of closures',
      () async {
        final runner = BenchmarkRunner(
          'implicit-test',
          config: const RunnerConfig(minSamples: 2, maxSamples: 4),
        );

        final syncResult = runner.run(() => 1000);
        expect(syncResult.samples, isNotEmpty);

        final asyncResult = await runner.runAsync(() async {
          await Future<void>.delayed(const Duration(microseconds: 1));
          return 'success-string';
        });
        expect(asyncResult.samples, isNotEmpty);
      },
    );
  });
}
