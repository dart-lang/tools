// Copyright 2011 Google Inc. All Rights Reserved.
// BenchmarkBase.dart

part of benchmark_harness;

class BenchmarkBase {
  final String name;

  // Empty constructor.
  const BenchmarkBase(String name) : this.name = name;

  // The benchmark code.
  // This function is not used, if both [warmup] and [exercise] are overwritten.
  void run() { }

  // Runs a short version of the benchmark. By default invokes [run] once.
  int warmup() {
    run();
    return 1;
  }

  // Exercices the benchmark. By default invokes [run] 10 times.
  int exercise() {
    int runs = 0;
    for (int i = 0; i < 10; i++) {
      run();
      runs++;
    }
    return runs;
  }

  // Not measured setup code executed prior to the benchmark runs.
  void setup() { }

  // Not measures teardown code executed after the benchark runs.
  void teardown() { }

  // Measures the score for this benchmark by executing it repeately until
  // time minimum has been reached.
  static List measureFor(Function f, int timeMinimum) {
    int time = 0;
    int iter = 0;
    int runs = 0;
    Stopwatch watch = new Stopwatch();
    watch.start();
    int elapsed = 0;
    while (elapsed < timeMinimum) {
      int r = f();
      runs += r;
      elapsed = watch.elapsedMilliseconds;
      iter++;
    }
    return [1000.0 * elapsed / iter, runs];
  }

  // Measures the score for the benchmark and returns it.
  List measure() {
    setup();
    // Warmup for at least 100ms. Discard result.
    measureFor(() { return this.warmup(); }, 100);
    // Run the benchmark for at least 2000ms.
    List result = measureFor(() { return this.exercise(); }, 2000);
    teardown();
    return result;
  }

  void report() {
    List result = measure();
    double score = result[0];
    int runs = result[1];
    print("$name(TotalRunTime): $score us.");
    print("$name(Runs): $runs.");
    print("$name(AverageRunTime): ${score/runs} us.");
  }

}
