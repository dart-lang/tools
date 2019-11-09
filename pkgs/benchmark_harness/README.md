# Dart Benchmark Harness

The Dart project benchmark harness is the recommended starting point when building a benchmark for Dart.

## Learning more

You can read more about [Benchmarking the Dart VM](https://www.dartlang.org/articles/server/benchmarking/).

## Interpreting Results

By default, the reported runtime is not for a single call to `run()`, but for
the average time it takes to call `run()` __10 times__. The
benchmark harness executes a 10-call timing loop repeatedly until 2 seconds
have elapsed; the reported result is the average of the runtimes for each
loop.

## Comparing Results

If you are running the same benchmark, on the same machine, running the same OS,
the reported run times can be carefully compared across runs.
Carefully because there are a variety of factors which
could cause error in the run time, for example, the load from
other applications running on your machine could alter the result.

Comparing the run time of different benchmarks is not recommended. 
In other words, don't compare apples with oranges.

## Features

* `BenchmarkBase` class that all new benchmarks should `extend`
* Two sample benchmarks (DeltaBlue & Richards)
* Template benchmark that you can copy and paste when building new benchmarks

## Getting Started

1\. Add the following to your project's **pubspec.yaml**

```
dependencies:
    benchmark_harness: any
```

2\. Install pub packages

```
pub install
```

3\. Add the following import:

```
import 'package:benchmark_harness/benchmark_harness.dart';
```

4\. Create a benchmark class which inherits from `BenchmarkBase`

## Example

Create a dart file in the [`benchmark/`](https://www.dartlang.org/tools/pub/package-layout#tests-and-benchmarks)
folder of your package.

```
// Import BenchmarkBase class.
import 'package:benchmark_harness/benchmark_harness.dart';

// Create a new benchmark by extending BenchmarkBase
class TemplateBenchmark extends BenchmarkBase {
  const TemplateBenchmark() : super('Template');

  static void main() {
    TemplateBenchmark().report();
  }

  // The benchmark code.
  @override
  void run() {
  }

  // Not measured setup code executed prior to the benchmark runs.
  @override
  void setup() { }

  // Not measured teardown code executed after the benchmark runs.
  @override
  void teardown() { }
}

main() {
  // Run TemplateBenchmark
  TemplateBenchmark.main();
}
```

### Output
```
Template(RunTime): 0.1568472448997197 us.
```
This is the average amount of time it takes to run `run()` 10 times.
> µs is an abbreviation for microseconds.

### Contributions

This package is carefully curated by the Dart team to exact specifications. Please open an issue with any proposed changes, before submitting a Pull Request.
