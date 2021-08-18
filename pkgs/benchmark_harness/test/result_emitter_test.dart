// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library result_emitter_test;

import 'package:benchmark_harness/benchmark_harness.dart';

import 'package:test/test.dart';

void main() {
  benchmarkHarnessTest();
}

class MockResultEmitter extends ScoreEmitter {
  int emitCount = 0;

  @override
  void emit(String name, double value) {
    emitCount++;
  }
}

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

      expect(emitter.emitCount, equals(1));
    });
  });
}
