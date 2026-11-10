// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'package:csslib/parser.dart';

/// Compare baseline and optimized branches:
/// dart run benchmark/font_hash_benchmark.dart
///
/// Many font styles share the same size, as they do in document rendering.
/// The old hash function collapsed most of them into the same bucket.
void main() {
  const count = 2000;
  const passes = 3;
  final fonts = List.generate(
    count,
    (i) => Font(size: 16, family: ['font-$i']),
  );

  // Warm up compilation and the hash-table implementation.
  for (var i = 0; i < 2; i++) {
    final warmup = <Font, int>{};
    for (var j = 0; j < fonts.length; j++) {
      warmup[fonts[j]] = j;
    }
  }

  final stopwatch = Stopwatch()..start();
  var sum = 0;
  for (var pass = 0; pass < passes; pass++) {
    final map = <Font, int>{};
    for (var i = 0; i < fonts.length; i++) {
      map[fonts[i]] = i;
    }
    for (final font in fonts) {
      sum += map[font]!;
    }
  }
  stopwatch.stop();
  final elapsed = stopwatch.elapsedMicroseconds;
  print('Hash insert/lookup: $count fonts x $passes passes, '
      'sum=$sum, elapsed=$elapsed us');
}
