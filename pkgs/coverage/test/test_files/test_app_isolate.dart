// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

String fooSync(int x) {
  if (x == 42) {
    return '*' * x;
  }
  return new List.generate(x, (_) => 'xyzzy').join(' ');
}

Future<String> fooAsync(int x) async {
  if (x == 42) {
    return '*' * x;
  }
  return new List.generate(x, (_) => 'xyzzy').join(' ');
}

/// The number of covered lines is tested and expected to be 4.
///
/// If you modify this method, you may have to update the tests!
void isolateTask(List<dynamic> threeThings) {
  sleep(const Duration(milliseconds: 500));

  fooSync(42);
  fooAsync(42).then((_) {
    SendPort port = threeThings.first;
    int sum = threeThings[1] + threeThings[2];
    port.send(sum);
  });
}
