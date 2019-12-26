// Copyright 2012 Google Inc. All Rights Reserved.

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

  // Not measures teardown code executed after the benchark runs.
  @override
  void teardown() {}
}

void main() {
  // Run TemplateBenchmark
  TemplateBenchmark.main();
}
