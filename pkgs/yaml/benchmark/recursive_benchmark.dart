// Copyright (c) 2026, the Dart project authors.
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:yaml/src/equality.dart';

const numTrials = 20;
const runsPerTrial = 100000;

void main() {
  // Create a self-referential list.
  var list = <Object?>[];
  list.add(list);

  // Create a self-referential map.
  var map = deepEqualsMap<Object?, Object?>();
  map['self'] = map;

  // Create a deep self-referential list (depth 100).
  var deepList = <Object?>[];
  var current = deepList;
  for (var i = 0; i < 100; i++) {
    var next = <Object?>[];
    current.add(next);
    current = next;
  }
  current.add(deepList); // Cycle back!

  // Create a map containing both.
  var m1 = deepEqualsMap<Object?, Object?>();
  m1[list] = 'list';
  m1[map] = 'map';
  m1[deepList] = 'deepList';

  var best = double.infinity;
  var stopwatch = Stopwatch();

  for (var i = 0; i <= numTrials; i++) {
    stopwatch.reset();
    stopwatch.start();

    for (var j = 0; j < runsPerTrial; j++) {
      deepHashCode(list);
      deepHashCode(map);
      deepHashCode(deepList);
      deepHashCode(m1);
    }

    stopwatch.stop();
    var elapsed = stopwatch.elapsedMicroseconds / 1000 / runsPerTrial;

    if (elapsed >= best) continue;
    best = elapsed;

    if (i == 0) continue;
    print('Run #${i.toString().padLeft(3)}: ${elapsed.toStringAsFixed(6)}ms');
  }

  print('Best   : ${best.toStringAsFixed(6)}ms');
}
