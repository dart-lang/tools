// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
