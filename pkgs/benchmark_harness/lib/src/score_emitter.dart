// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'model/benchmark_result_models.dart';
import 'model/dart_environment.dart';
import 'result.dart';

abstract class ScoreEmitter {
  void emit(String testName, double value);
}

/// An emitter that can handle detailed benchmark results.
abstract class DetailedScoreEmitter extends ScoreEmitter {
  void emitDetailed(BenchmarkResult result);
}

class PrintEmitter implements DetailedScoreEmitter {
  const PrintEmitter();

  @override
  void emit(String testName, double value) {
    print('$testName(RunTime): $value us.');
  }

  @override
  void emitDetailed(BenchmarkResult result) {
    emit(result.name, result.median);
  }
}

/// Legacy interface for [ScoreEmitter].
abstract class ScoreEmitterV2 implements ScoreEmitter {
  @override
  void emit(
    String testName,
    double value, {
    String metric = 'RunTime',
    String unit,
  });
}

/// Legacy implementation of [PrintEmitter].
class PrintEmitterV2 implements ScoreEmitterV2 {
  const PrintEmitterV2();

  @override
  void emit(
    String testName,
    double value, {
    String metric = 'RunTime',
    String unit = '',
  }) {
    print(['$testName($metric):', value, if (unit.isNotEmpty) unit].join(' '));
  }
}

class JsonEmitter implements DetailedScoreEmitter {
  final Map<String, BenchmarkVariantResult> _results = {};

  @override
  void emit(String testName, double value) {
    _results[testName] = BenchmarkVariantResult(
      name: testName,
      variant: testName,
      platform: DartEnvironment.platform.value,
      timestamp: DateTime.now().toUtc(),
      environment: HostEnvironment.fromDartEnvironment(),
      metrics: RunMetrics(
        samplesCount: 1,
        meanUs: value,
        medianUs: value,
        stdDevUs: 0.0,
        cv: 0.0,
        confidenceInterval95: [value, value],
        isStable: true,
        convergenceThreshold: 0.0,
      ),
      warmupDiagnostics: const WarmupDiagnostics(warmupConverged: true),
      rawSamplesUs: [value],
    );
  }

  @override
  void emitDetailed(BenchmarkResult result) {
    _results[result.name] = BenchmarkVariantResult(
      name: result.name,
      variant: result.name,
      platform: DartEnvironment.platform.value,
      timestamp: DateTime.now().toUtc(),
      environment: HostEnvironment.fromDartEnvironment(),
      metrics: RunMetrics(
        samplesCount: result.samples.length,
        meanUs: result.mean,
        medianUs: result.median,
        stdDevUs: result.stdDev,
        cv: result.cv / 100.0,
        confidenceInterval95: [
          result.confidenceInterval.lowerBound,
          result.confidenceInterval.upperBound,
        ],
        isStable: result.isStable,
        convergenceThreshold: result.convergenceThreshold ?? 0.0,
      ),
      warmupDiagnostics: WarmupDiagnostics(warmupConverged: result.isStable),
      rawSamplesUs: result.samples,
    );
  }

  Map<String, dynamic> toJson() => {
    for (var entry in _results.entries) entry.key: entry.value.toJson(),
  };

  /// Returns [toJson] encoded as a [String].
  @override
  String toString() => jsonEncode(toJson());
}
