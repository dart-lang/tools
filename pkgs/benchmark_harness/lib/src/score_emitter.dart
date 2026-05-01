// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
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

/// Outputs results as JSON.
class JsonEmitter implements DetailedScoreEmitter {
  final Map<String, dynamic> _results = {};

  @override
  void emit(String testName, double value) {
    _results[testName] = {'median': value};
  }

  @override
  void emitDetailed(BenchmarkResult result) {
    _results[result.name] = {
      'median': result.median,
      'mean': result.mean,
      'stdDev': result.stdDev,
      'cv': result.cv,
      'samples': result.samples,
    };
  }

  @override
  String toString() => jsonEncode(_results);
}
