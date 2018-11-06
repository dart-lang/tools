// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:math' show Random;

import 'package:graphs/graphs.dart';

void main() {
  final _rnd = Random(1);
  final size = 1000;
  final graph = HashMap<int, List<int>>();

  for (var i = 0; i < size * 5; i++) {
    final toList = graph.putIfAbsent(_rnd.nextInt(size), () => <int>[]);

    final toValue = _rnd.nextInt(size);
    if (!toList.contains(toValue)) {
      toList.add(toValue);
    }
  }

  var counts = <int>[];

  final testOutput =
      shortestPath(0, size - 1, (v) => v, (e) => graph[e] ?? []).toString();
  print(testOutput);
  assert(testOutput == '[258, 252, 819, 999]');

  for (var i = 0; i < 50; i++) {
    var count = 0;
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(milliseconds: 100)) {
      count++;
      final length =
          shortestPath(0, size - 1, (v) => v, (e) => graph[e] ?? []).length;
      assert(length == 4, '$length');
    }
    print(count);
    counts.add(count);
  }

  print('max iterations in 1s: ${(counts..sort()).last}');
}
