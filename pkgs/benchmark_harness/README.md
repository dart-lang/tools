# Dart Benchmark Harness #
==========================

## Introduction ##

The Dart project benchmark harness is the recommended starting point when building a benchmark for Dart.

## Features ##

* ```BenchmarkBase``` class that all new benchmarks should ```extend```
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

4\. Create a benchmark class which inherits from ```BenchmarkBase```

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
