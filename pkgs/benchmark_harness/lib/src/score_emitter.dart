part of benchmark_harness;

abstract class ScoreEmitter {
  void emit(String testName, double value);
}

class PrintEmitter implements ScoreEmitter {
  const PrintEmitter();

  @override
  void emit(String testName, double value) {
    print('$testName(RunTime): $value us.');
  }
}
