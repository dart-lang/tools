// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/src/bench_command/bench_options.dart';
import 'package:benchmark_harness/src/bench_command/compile_and_run.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

void main() {
  test('readme', () async {
    final process = await TestProcess.start(Platform.executable, [
      'bin/bench.dart',
      '--help',
    ]);

    await process.shouldExit(isZero);
    final stdoutContent = await process.stdout.rest.toList();
    final trimmed = stdoutContent.map((e) => e.trimRight()).join('\n');

    final readmeFile = File('README.md').readAsStringSync();

    expect(readmeFile, contains(trimmed));
  });

  group('invoke the command', () {
    late String testFilePath;

    setUp(() async {
      await d.file('input.dart', _testDartFile).create();
      testFilePath = p.join(d.sandbox, 'input.dart');
    });

    group('BenchOptions.fromArgs', () {
      test('options parsing', () async {
        final options = BenchOptions.fromArgs([
          '--flavor',
          'aot,jit',
          '--target',
          testFilePath,
        ]);

        await expectLater(
          () => compileAndRun(options),
          prints(
            stringContainsInOrder([
              'AOT - COMPILE',
              testFilePath,
              'AOT - RUN',
              'JIT - RUN',
              testFilePath,
            ]),
          ),
        );
      });

      test('isolate-mode JIT execution', () async {
        final options = BenchOptions.fromArgs([
          '--flavor',
          'jit',
          '--target',
          testFilePath,
          '--isolate-mode',
        ]);

        await expectLater(
          () => compileAndRun(options),
          prints(stringContainsInOrder(['JIT (ISOLATE) - RUN', testFilePath])),
        );
      });

      test('generative wrapper compiling and execution', () async {
        await d.file('benchmarks.dart', _testBenchmarksDartFile).create();

        final options = BenchOptions.fromArgs([
          '--flavor',
          'jit',
          '--target',
          p.join(d.sandbox, 'benchmarks.dart'),
        ]);

        await expectLater(
          () => compileAndRun(options),
          prints(stringContainsInOrder(['JIT - RUN', 'wrapper.dart'])),
        );
      });

      test('generative wrapper JIT execution via CLI without '
          'explicit package config', () async {
        await d.file('benchmarks.dart', _testBenchmarksDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          'bin/bench.dart',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'benchmarks.dart'),
        ]);

        await expectLater(
          process.stdout,
          emitsThrough(contains('wrapper.dart')),
        );
        await process.shouldExit(isZero);
      });

      test('validate JIT execution via CLI', () async {
        await d.file('slow_bench.dart', _testSlowBenchmarksDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          'validate',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'slow_bench.dart'),
        ]);

        await expectLater(
          process.stderr,
          emitsThrough(
            contains('Validation: Benchmark "Slow" passed smoke run'),
          ),
        );
        await process.shouldExit(isZero);
      });

      test('guideline abort on slow benchmark JIT', () async {
        await d.file('slow_bench.dart', _testSlowBenchmarksDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'slow_bench.dart'),
        ]);

        await expectLater(
          process.stderr,
          emitsThrough(contains('CalibrationException')),
        );
        await process.shouldExit(isNonZero);
      });

      test('bypasses guideline abort with force-run JIT', () async {
        await d.file('slow_bench.dart', _testSlowBenchmarksDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'slow_bench.dart'),
          '--force-run',
        ]);

        await expectLater(
          process.stderr,
          emitsThrough(contains('Calibration guidelines violated')),
        );
        await process.shouldExit(isZero);
      });

      test('validate JIT flags dead-code optimizations', () async {
        await d.file('dead_code_bench.dart', _testDeadCodeDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          'validate',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'dead_code_bench.dart'),
        ]);

        await expectLater(
          process.stderr,
          emitsThrough(
            anyOf(
              contains(
                'Validation Warning: Benchmark "Empty" may be optimized',
              ),
              contains('Validation: Benchmark "Empty" passed smoke run'),
            ),
          ),
        );
        await process.shouldExit(isZero);
      });

      test('JIT flags timing jitter / instability warnings', () async {
        await d.file('jitter_bench.dart', _testJitterDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--target',
          p.join(d.sandbox, 'jitter_bench.dart'),
        ]);

        await expectLater(
          process.stderr,
          emitsThrough(contains('without proving convergence for "Jitter"')),
        );
        await process.shouldExit(isZero);
      });

      test('legacy --json output parsing', () async {
        await d.file('legacy_bench.dart', _testDeadCodeDartFile).create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--json',
          '--target',
          p.join(d.sandbox, 'legacy_bench.dart'),
        ]);

        await process.shouldExit(isZero);
        final stdoutContent = (await process.stdout.rest.toList()).join('\n');
        final decoded = jsonDecode(stdoutContent) as Map<String, dynamic>;
        expect(decoded, contains('jit'));
        final jitResults = decoded['jit'] as Map<String, dynamic>;
        expect(jitResults, contains('Empty'));
        final emptyResult = jitResults['Empty'] as Map<String, dynamic>;
        final metrics = emptyResult['metrics'] as Map<String, dynamic>;
        expect(metrics, contains('median_us'));
      });

      test('custom compiler-flag forwarding', () async {
        final options = BenchOptions.fromArgs([
          '--flavor',
          'jit',
          '--target',
          testFilePath,
          '--compiler-flag=-Dcustom_flag=true',
        ]);

        expect(options.compilerFlags, contains('-Dcustom_flag=true'));

        await expectLater(
          () => compileAndRun(options),
          prints(stringContainsInOrder(['JIT - RUN', '-Dcustom_flag=true'])),
        );
      });

      test('isolate-mode unhandled exception propagates and '
          'throws BenchException', () async {
        await d
            .file('failing_bench.dart', _testFailingBenchmarksDartFile)
            .create();

        final options = BenchOptions.fromArgs([
          '--flavor',
          'jit',
          '--target',
          p.join(d.sandbox, 'failing_bench.dart'),
          '--isolate-mode',
        ]);

        await expectLater(
          () => compileAndRun(options),
          throwsA(isA<BenchException>()),
        );
      });

      test('validate JIT execution aborts with FormatException on '
          'malformed output', () async {
        await d
            .file('malformed_bench.dart', _testMalformedBenchmarksDartFile)
            .create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--json',
          '--target',
          p.join(d.sandbox, 'malformed_bench.dart'),
        ]);

        await expectLater(
          process.stdout,
          emitsThrough(contains('Failed to decode JIT JSON')),
        );
        await process.shouldExit(isNonZero);
      });

      test('validate JIT execution extracts JSON cleanly when stdout has '
          'leading warnings', () async {
        await d
            .file('polluted_bench.dart', _testPollutedBenchmarksDartFile)
            .create();

        final process = await TestProcess.start(Platform.executable, [
          if (Platform.packageConfig != null)
            '--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}',
          'bin/bench.dart',
          '-f',
          'jit',
          '--json',
          '--target',
          p.join(d.sandbox, 'polluted_bench.dart'),
        ]);

        await process.shouldExit(isZero);
        final stdoutContent = (await process.stdout.rest.toList()).join('\n');
        final decoded = jsonDecode(stdoutContent) as Map<String, dynamic>;
        expect(decoded, contains('jit'));
        final jitResults = decoded['jit'] as Map<String, dynamic>;
        expect(jitResults, contains('Empty'));
      });

      test('rest args not supported', () async {
        expect(
          () => BenchOptions.fromArgs(['--flavor', 'aot,jit', testFilePath]),
          throwsFormatException,
        );
      });
    });

    for (var bench in RuntimeFlavor.values) {
      test('$bench', skip: _skipWasm(bench), () async {
        await expectLater(
          () => compileAndRun(
            BenchOptions(flavor: {bench}, target: testFilePath),
          ),
          prints(
            stringContainsInOrder([
              if (bench != RuntimeFlavor.jit) ...[
                '${bench.name.toUpperCase()} - COMPILE',
                testFilePath,
              ],
              '${bench.name.toUpperCase()} - RUN',
            ]),
          ),
        );
      });
    }
  });
}

// Can remove this once the min tested SDK on GitHub is >= 3.7
String? _skipWasm(RuntimeFlavor flavor) {
  if (flavor != RuntimeFlavor.wasm) {
    return null;
  }
  final versionBits = Platform.version.split('.');
  final versionValues = versionBits.take(2).map(int.parse).toList();

  return switch ((versionValues[0], versionValues[1])) {
    // If major is greater than 3, it's definitely >= 3.7
    (int m, _) when m > 3 => null,
    // If major is 3, check the minor version
    (3, int n) when n >= 7 => null,
    // All other cases (major < 3, or major is 3 but minor < 7)
    _ => 'Requires Dart >= 3.7',
  };
}

const _testDartFile = '''
void main() {
  // outputs 0 is JS
  // 8589934592 everywhere else
  print(1 << 33);
}
''';

const _testBenchmarksDartFile = '''
import 'package:benchmark_harness/benchmark_harness.dart';

final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'Growable List',
    variants: [
      BenchmarkVariant(
        name: 'Growable',
        run: () => <int>[...Iterable.generate(10)],
      ),
    ],
    config: const RunnerConfig(minSamples: 2, maxSamples: 4),
  ),
];
''';

const _testSlowBenchmarksDartFile = '''
import 'dart:io';
import 'package:benchmark_harness/benchmark_harness.dart';

class SlowBenchmark extends BenchmarkBase {
  int count = 0;
  SlowBenchmark() : super('Slow');
  @override
  void run() {
    count++;
    if (count == 2) {
      sleep(const Duration(milliseconds: 250));
    }
  }
}

void main() => SlowBenchmark().report();
''';

const _testDeadCodeDartFile = '''
import 'package:benchmark_harness/benchmark_harness.dart';

class EmptyBenchmark extends BenchmarkBase {
  EmptyBenchmark() : super('Empty');
  @override
  void run() {}
}

void main() => EmptyBenchmark().report();
''';

const _testJitterDartFile = '''
import 'dart:io';
import 'package:benchmark_harness/benchmark_harness.dart';

int count = 0;

final List<Benchmark> benchmarks = [
  Benchmark(
    title: 'Jitter Suite',
    variants: [
      BenchmarkVariant(
        name: 'Jitter',
        run: () {
          count++;
          if (count % 2 == 0) {
            sleep(const Duration(microseconds: 500));
          } else {
            sleep(const Duration(microseconds: 1));
          }
        },
      ),
    ],
    config: const RunnerConfig(
      targetSampleMicros: 1,
      minSamples: 10,
      maxSamples: 30,
    ),
  ),
];
''';

const _testFailingBenchmarksDartFile = '''
void main() {
  throw StateError('Failing benchmark execution');
}
''';

const _testMalformedBenchmarksDartFile = '''
void main() {
  print("This is definitely not valid JSON and not a legacy benchmark output!");
}
''';

const _testPollutedBenchmarksDartFile = '''
import 'package:benchmark_harness/benchmark_harness.dart';

class EmptyBenchmark extends BenchmarkBase {
  EmptyBenchmark() : super('Empty');
  @override
  void run() {}
}

void main() {
  print("Warning: Random timezone or VM calibration warning line that should be skipped!");
  EmptyBenchmark().report();
  print("Info: Another trailing diagnostic trace to ignore!");
}
''';
