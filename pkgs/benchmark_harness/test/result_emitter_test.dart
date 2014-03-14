library result_emitter_test;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:unittest/mock.dart';

import 'fixed-unittest.dart';

void main() {
  benchmarkHarnessTest();
}

class MockResultEmitter extends Mock implements ScoreEmitter {
  var hasEmitted = false;

  MockResultEmitter() {
    when(callsTo('emit')).alwaysCall(fakeEmit);
  }

  void fakeEmit(String name, double value) {
    hasEmitted = true;
  }

  // Added to quiet an analyzer warning.
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Create a new benchmark which has an emitter.
class BenchmarkWithResultEmitter extends BenchmarkBase {
  const BenchmarkWithResultEmitter(ScoreEmitter emitter) : super("Template", emitter: emitter);

  void run() { }

  void setup() { }

  void teardown() { }
}

benchmarkHarnessTest() {
  MockResultEmitter createMockEmitter() {
    MockResultEmitter emitter = new MockResultEmitter();
    return emitter;
  }

  describe('ResultEmitter', () {
    it('should be called when emitter is provided', () {
      MockResultEmitter emitter = createMockEmitter();
      var testBenchmark = new BenchmarkWithResultEmitter(emitter);
      testBenchmark.report();
      emitter.getLogs(callsTo('emit')).verify(happenedOnce);
    });
  });
}
