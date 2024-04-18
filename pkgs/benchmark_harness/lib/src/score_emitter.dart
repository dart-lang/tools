// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

abstract class ScoreEmitter {
  void emit(String testName, double value,
      {String metric = 'RunTime', String unit});
}

class PrintEmitter implements ScoreEmitter {
  const PrintEmitter();

  @override
  void emit(String testName, double value,
      {String metric = 'RunTime', String unit = ''}) {
    print(['$testName($metric):', value, if (unit.isNotEmpty) unit].join(' '));
  }
}
