library result_emitter_test;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:mockito/mockito.dart';

import 'package:test/test.dart';

void main() {
  benchmarkHarnessTest();
}

class MockResultEmitter extends Mock implements ScoreEmitter {}

// Create a new benchmark which has an emitter.
class BenchmarkWithResultEmitter extends BenchmarkBase {
  const BenchmarkWithResultEmitter(ScoreEmitter emitter)
      : super('Template', emitter: emitter);

  @override
  void run() {}

  @override
  void setup() {}

  @override
  void teardown() {}
}

void benchmarkHarnessTest() {
  MockResultEmitter createMockEmitter() {
    var emitter = MockResultEmitter();
    return emitter;
  }

  group('ResultEmitter', () {
    test('should be called when emitter is provided', () {
      var emitter = createMockEmitter();
      var testBenchmark = BenchmarkWithResultEmitter(emitter);
      testBenchmark.report();

      verify(emitter.emit(any, any)).called(1);
    });
  });
}
