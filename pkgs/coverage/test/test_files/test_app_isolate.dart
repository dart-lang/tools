// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

const int answer = 42;

String fooSync(int x) {
  if (x == answer) {
    return '*' * x;
  }
  return List.generate(x, (_) => 'xyzzy').join(' ');
}

Future<String> fooAsync(int x) async {
  if (x == answer) {
    return '*' * x;
  }
  return List.generate(x, (_) => 'xyzzy').join(' ');
}

/// The number of covered lines is tested and expected to be 4.
///
/// If you modify this method, you may have to update the tests!
void isolateTask(dynamic threeThings) {
  sleep(const Duration(milliseconds: 500));

  fooSync(answer);
  fooAsync(answer).then((_) {
    final port = threeThings.first as SendPort;
    final sum = (threeThings[1] + threeThings[2]) as int;
    port.send(sum);
  });
}
