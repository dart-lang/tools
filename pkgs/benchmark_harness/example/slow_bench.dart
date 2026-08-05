import 'dart:io';
import 'package:benchmark_harness/benchmark_harness.dart';

class SlowBenchmark extends BenchmarkBase {
  SlowBenchmark() : super('Slow');

  @override
  void run() => sleep(const Duration(milliseconds: 250));
}

void main() => SlowBenchmark().report();
