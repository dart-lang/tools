// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.util_test;

import 'dart:async';

import 'package:coverage/src/util.dart';
import 'package:test/test.dart';

const _failCount = 5;
const _delay = const Duration(milliseconds: 10);

void main() {
  test('retry', () async {
    int count = 0;
    var stopwatch = new Stopwatch()..start();

    Future failCountTimes() async {
      expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));

      while (count < _failCount) {
        count++;
        throw 'not yet!';
      }
      return 42;
    }

    var value = await retry(failCountTimes, _delay);

    expect(value, 42);
    expect(count, _failCount);
    expect(stopwatch.elapsed, greaterThanOrEqualTo(_delay * count));
  });
}
