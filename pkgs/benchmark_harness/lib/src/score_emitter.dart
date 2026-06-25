// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'measurement.dart';

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

/// New interface for [ScoreEmitter]. [ScoreEmitter] will be changed to
/// this interface in the next major version release, and this class will
/// be deprecated and removed.  That release will be a breaking change.
abstract class ScoreEmitterV2 implements ScoreEmitter {
  @override
  void emit(
    String testName,
    double value, {
    String metric = 'RunTime',
    String unit,
  });
}

/// New implementation of [PrintEmitter] implementing the [ScoreEmitterV2]
/// interface.  [PrintEmitter] will be changed to this implementation in the
/// next major version release.
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

/// Prints [measurement] to stdout in a human-readable format with
/// average, coefficient of variation, sample count, and minimum sample.
/// Used by `BenchmarkBase.reportDetailed`; exposed publicly so callers
/// writing custom rendering paths can reuse the same format or compose
/// their own.
void printDetailedMeasurement(
  String testName,
  DetailedMeasurement measurement,
) {
  final avgMs = (measurement.meanMicros / 1000).toStringAsFixed(3);
  final medianMs = (measurement.medianMicros / 1000).toStringAsFixed(3);
  final minMs = (measurement.minMicros / 1000).toStringAsFixed(3);
  final cv = measurement.coefficientOfVariation.toStringAsFixed(2);
  print(
    '$testName: avg=$avgMs ms'
    ' · median=$medianMs ms'
    ' · CV=$cv%'
    ' · samples=${measurement.samples.length}'
    ' · min=$minMs ms',
  );
}
