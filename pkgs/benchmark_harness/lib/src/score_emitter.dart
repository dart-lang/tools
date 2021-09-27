// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
