// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'package:csslib/parser.dart';

/// Run with: dart run benchmark/tokenizer_benchmark.dart
///
/// Compare identical inputs, SDKs and modes across revisions. This exercises
/// the repeated short style declarations common to inline HTML rendering.
void main() {
  const stylesheet = '''
.entry-שלום {
  font-family: FrankRuhl;
  font-size: 18px;
  line-height: 1.4;
  color: #334455;
  background-color: rgba(25, 30, 35, 0.5);
  margin-right: 0.5em;
  padding: 2px 4px;
}
''';
  const iterations = 20000;
  // Warm up the parser/JIT before measuring.
  for (var i = 0; i < 1000; i++) {
    parse(stylesheet);
  }
  final stopwatch = Stopwatch()..start();
  var rules = 0;
  for (var i = 0; i < iterations; i++) {
    rules += parse(stylesheet).topLevels.length;
  }
  stopwatch.stop();
  final elapsed = stopwatch.elapsedMicroseconds;
  final perParse = elapsed / iterations;
  print('Parsed $rules rules in $elapsed us ($perParse us/parse)');
}
