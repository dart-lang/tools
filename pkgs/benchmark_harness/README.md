# Dart Benchmark Harness #
==========================

## Introduction ##

The Dart project benchmark harness is the recommended starting point when building a benchmark for Dart.

## Interpreting Results ##

By default, the benchmark harness calls the `run` method 10 times
repeatedly until 2 seconds have elapsed. This means that
the reported run time is not for a single call to `run` but an average across
10.

## Comparing Results ##

If you are running the same benchmark, on the same machine, running the same OS,
the reported run times can be carefully compared across runs.
Carefully because there are a variety of factors which
could cause error in the run time, for example, the load from
other applications running on your machine could alter the result.

Comparing the run time of different benchmarks is not recommended. 
In other words, don't compare apples with oranges.

## Features ##

* `BenchmarkBase` class that all new benchmarks should `extend`
* Two sample benchmarks (DeltaBlue & Richards)
* Template benchmark that you can copy and paste when building new benchmarks

## Getting Started ##

1\. Add the following to your project's **pubspec.yaml**

```
dependencies:
    benchmark_harness:
        git: https://github.com/dart-lang/benchmark_harness.git
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

## Example ##

```
// Import BenchmarkBase class.
import 'package:benchmark_harness/benchmark_harness.dart';

// Create a new benchmark by extending BenchmarkBase
class TemplateBenchmark extends BenchmarkBase {
  const TemplateBenchmark() : super("Template");

  static void main() {
    new TemplateBenchmark().report();
  }

  // The benchmark code.
  void run() {
  }

  // Not measured setup code executed prior to the benchmark runs.
  void setup() { }

  // Not measures teardown code executed after the benchark runs.
  void teardown() { }
}

main() {
  // Run TemplateBenchmark
  TemplateBenchmark.main();
}
```
