// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'package:csslib/parser.dart';

/// Compare the same generated stylesheet on baseline and optimized revisions:
/// dart run benchmark/nested_flatten_benchmark.dart
void main() {
  const entries = 1000;
  const iterations = 15;
  final css = StringBuffer();
  for (var i = 0; i < entries; i++) {
    css.write('.section$i { color: red; .nested { width: 1px; } }');
  }
  final text = css.toString();

  for (var i = 0; i < 3; i++) {
    compile(text);
  }

  final stopwatch = Stopwatch()..start();
  var emittedRules = 0;
  for (var i = 0; i < iterations; i++) {
    emittedRules += compile(text).topLevels.length;
  }
  stopwatch.stop();
  final elapsed = stopwatch.elapsedMicroseconds;
  print(
    'Flattened $emittedRules rules over $iterations parses in $elapsed us '
    '(${elapsed / iterations} us/parse)',
  );
}
