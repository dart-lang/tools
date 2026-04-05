// Copyright (c) 2026, the Dart project authors.
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:yaml/src/equality.dart';

const numTrials = 100;
const runsPerTrial = 1000;

void main() {
  // Create a self-referential list.
  var list = <Object?>[];
  list.add(list);

  // Create a self-referential map.
  var map = deepEqualsMap<Object?, Object?>();
  map['self'] = map;

  var best = double.infinity;

  for (var i = 0; i <= numTrials; i++) {
    var start = DateTime.now();

    for (var j = 0; j < runsPerTrial; j++) {
      deepHashCode(list);
      deepHashCode(map);

      var m1 = deepEqualsMap<Object?, Object?>();
      m1[list] = 'list';
      m1[map] = 'map';

      deepHashCode(m1);
    }

    var elapsed =
        DateTime.now().difference(start).inMilliseconds / runsPerTrial;

    if (elapsed >= best) continue;
    best = elapsed;

    if (i == 0) continue;
    print('Run #${i.toString().padLeft(3)}: ${elapsed.toStringAsFixed(3)}ms');
  }

  print('Best   : ${best.toStringAsFixed(3)}ms');
}
