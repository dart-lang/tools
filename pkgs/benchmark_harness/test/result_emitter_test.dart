library remote;

import 'fixed-unittest.dart';
import 'package:unittest/mock.dart';
import 'package:di/di.dart';
import 'package:di/dynamic_injector.dart';
import 'package:benchmark_harness/benchmark_harness.dart';


void main() {
  benchmarkHarnessTest();
}

class MockResultEmitter extends Mock implements ScoreEmitter {
  var hasEmitted = false;

  MockResultEmitter() {
    when(callsTo('emit')).alwaysCall(fakeEmit);
  }

  void fakeEmit(double value) {
    hasEmitted = true;
  }
}

// Create a new benchmark which has an emitter.
class BenchmarkWithResultEmitter extends BenchmarkBase {
  const BenchmarkWithResultEmitter(ScoreEmitter emitter) : super("Template", emitter: emitter);

  void run() { }

  void setup() { }

  void teardown() { }
}

// Create a new benchmark which has no emitter
class BenchmarkWithoutResultEmitter extends BenchmarkBase {
  const BenchmarkWithoutResultEmitter() : super("Template");

  void run() { }

  void setup() { }

  void teardown() { }
}

benchmarkHarnessTest() {
  MockResultEmitter createMockEmitter() {
    MockResultEmitter emitter = new MockResultEmitter();
    emitter.when(callsTo('emit'));
    return emitter;
  }

  describe('ResultEmitter', () {
    it('should be called when emitter is provided', () {
      MockResultEmitter emitter = createMockEmitter();
      Module module = new Module()..value(ScoreEmitter, emitter )
          ..type(BenchmarkWithResultEmitter);
      Injector i = new DynamicInjector(modules: [module]);

      var testBenchmark = i.get(BenchmarkWithResultEmitter);
      testBenchmark.report();
      emitter.getLogs(callsTo('emit')).verify(happenedOnce);
    });
  });

  describe('ResultEmitter', () {
    it('should not be called when emitter is not provided', () {
      MockResultEmitter emitter = createMockEmitter();
      Module module = new Module()..value(ScoreEmitter, emitter )
          ..type(BenchmarkWithoutResultEmitter);
      Injector i = new DynamicInjector(modules: [module]);

      var testBenchmark = i.get(BenchmarkWithoutResultEmitter);
      testBenchmark.report();
      emitter.getLogs(callsTo('emit')).verify(neverHappened);
    });
  });
}