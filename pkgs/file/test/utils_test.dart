// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('floorAndCeilProduceExactSecondDateTime', () {
    var time = DateTime.fromMicrosecondsSinceEpoch(1001);
    var lower = floor(time);
    var upper = ceil(time);
    expect(lower.millisecond, 0);
    expect(upper.millisecond, 0);
    expect(lower.microsecond, 0);
    expect(upper.microsecond, 0);
  });

  test('floorAndCeilWorkWithNow', () {
    var time = DateTime.now();
    var lower = time.difference(floor(time)).inMicroseconds;
    var upper = ceil(time).difference(time).inMicroseconds;
    expect(lower, lessThan(1000000));
    expect(upper, lessThanOrEqualTo(1000000));
  });

  test('floorAndCeilWorkWithExactSecondDateTime', () {
    var time = DateTime.parse('1999-12-31 23:59:59');
    var lower = floor(time);
    var upper = ceil(time);
    expect(lower, time);
    expect(upper, time);
  });

  test('floorAndCeilWorkWithInexactSecondDateTime', () {
    var time = DateTime.parse('1999-12-31 23:59:59.500');
    var lower = floor(time);
    var upper = ceil(time);
    var difference = upper.difference(lower);
    expect(difference.inMicroseconds, 1000000);
  });
}
