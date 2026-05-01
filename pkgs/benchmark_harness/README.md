[![Build Status](https://github.com/dart-lang/tools/actions/workflows/benchmark_harness.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/benchmark_harness.yaml)
[![pub package](https://img.shields.io/pub/v/benchmark_harness.svg)](https://pub.dev/packages/benchmark_harness)
[![package publisher](https://img.shields.io/pub/publisher/benchmark_harness.svg)](https://pub.dev/packages/benchmark_harness/publisher)

The Dart project benchmark harness is the recommended starting point when
building a benchmark for Dart.

## Interpreting Results

By default, the reported runtime in `BenchmarkBase` is not for a single call to
`run()`, but for the average time it takes to call `run()` __10 times__ for
legacy reasons. The benchmark harness executes a 10-call timing loop repeatedly
until 2 seconds have elapsed; the reported result is the average of the runtimes
for each loop. This behavior will change in a future major version.

Benchmarks extending `BenchmarkBase` can opt into the reporting the average time
to call `run()` once by overriding the `exercise` method:

```dart
  @override
  void exercise() => run();
```

`AsyncBenchmarkBase` already reports the average time to call `run()` __once__.

## Comparing Results

If you are running the same benchmark, on the same machine, running the same OS,
the reported run times can be carefully compared across runs.
Carefully because there are a variety of factors which
could cause error in the run time, for example, the load from
other applications running on your machine could alter the result.

Comparing the run time of different benchmarks is not recommended. 
In other words, don't compare apples with oranges.

## Features

* `BenchmarkBase` class that all new benchmarks should `extend`.
* `AsyncBenchmarkBase` for asynchronous benchmarks.
* Template benchmark that you can copy and paste when building new benchmarks.

## Getting Started

1. Add the following to your project's **pubspec.yaml**

```yaml
dependencies:
    benchmark_harness: any
```

2. Install pub packages

```sh
dart pub install
```

3. Add the following import:

```dart
import 'package:benchmark_harness/benchmark_harness.dart';
```

4. Create a benchmark class which inherits from `BenchmarkBase` or
    `AsyncBenchmarkBase`.

## Example

Create a dart file in the
[`benchmark/`](https://dart.dev/tools/pub/package-layout#tests-and-benchmarks)
folder of your package.

```dart
// Import BenchmarkBase class.
import 'package:benchmark_harness/benchmark_harness.dart';

// Create a new benchmark by extending BenchmarkBase
class TemplateBenchmark extends BenchmarkBase {
  const TemplateBenchmark() : super('Template');

  static void main() {
    const TemplateBenchmark().report();
  }

  // The benchmark code.
  @override
  void run() {}

  // Not measured setup code executed prior to the benchmark runs.
  @override
  void setup() {}

  // Not measured teardown code executed after the benchmark runs.
  @override
  void teardown() {}

  // To opt into the reporting the time per run() instead of per 10 run() calls.
  //@override
  //void exercise() => run();
}

void main() {
  // Run TemplateBenchmark
  TemplateBenchmark.main();
}
```

### Output

```console
Template(RunTime): 0.1568472448997197 us.
```

This is the average amount of time it takes to run `run()` 10 times for
`BenchmarkBase` and once for `AsyncBenchmarkBase`.
> `us` is an abbreviation for microseconds.

## Detailed measurement (CV%)

For benchmarks where one `run()` is comfortably above the timer noise
floor (≥ ~100 µs, typically ms-scale), `BenchmarkBase` exposes
`reportDetailed()` which times each `run()` call individually and emits a
median, coefficient of variation, sample count, and minimum sample
alongside the mean. Use it to gauge how stable a measurement is.

```dart
class JsonParse extends BenchmarkBase {
  const JsonParse() : super('JsonParse');

  @override
  void run() {
    // ~5 ms of work
  }
}

void main() {
  const JsonParse().reportDetailed();
}
```

```console
JsonParse: avg=4.812 ms · median=4.785 ms · CV=2.13% · samples=415 · min=4.703 ms
```

`reportDetailed` always calls `run()` directly (any `exercise` override
is bypassed), so the printed mean is *per `run()` call*, not per 10
calls. The default time budget is 2 seconds; pass
`reportDetailed(minimumMillis: 10000)` to collect more samples on slow
benchmarks. CV computed from very few samples carries large uncertainty
— aim for at least a few dozen.

For custom rendering (JSON, CSV, etc.), call `measureDetailed()` and
format the returned `DetailedMeasurement` (which exposes `samples`,
`meanMicros`, `medianMicros`, `minMicros`, `stddevMicros`,
`coefficientOfVariation`) yourself.

## `bench` command

A convenience command available in `package:benchmark_harness`.

If a package depends on `benchmark_harness`, invoke the command by running

```shell
dart run benchmark_harness:bench
```

If not, you can use this command by activating it.

```shell
dart pub global activate benchmark_harness
dart pub global run benchmark_harness:bench
```

Output from `dart run benchmark_harness:bench --help`

```
Runs a dart script in a number of runtimes.

Meant to make it easy to run a benchmark executable across runtimes to validate
performance impacts.

-f, --flavor
          [aot]     Compile and run as a native binary.
          [jit]     Run as-is without compilation, using the just-in-time (JIT) runtime.
          [js]      Compile to JavaScript and run on node.
          [wasm]    Compile to WebAssembly and run on node.

    --target        The target script to compile and run.
                    (defaults to "benchmark/benchmark.dart")
-h, --help          Print usage information and quit.
-v, --verbose       Print the full stack trace if an exception is thrown.
```

Example usage:

```shell
dart run benchmark_harness:bench --flavor aot --target example/template.dart

AOT - COMPILE
/dart_installation/dart-sdk/bin/dart compile exe example/template.dart -o /temp_dir/bench_1747680526905_GtfAeM/out.exe

Generated: /temp_dir/bench_1747680526905_GtfAeM/out.exe

AOT - RUN
/temp_dir/bench_1747680526905_GtfAeM/out.exe

Template(RunTime): 0.005620051244379949 us.
```