// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';

void main() {
  final stopwatch = Stopwatch()..start();
  final text = '''
foo bar baz
whiz bang boom
zip zap zop
''' *
      100;
  for (var i = 0; i < 100000; i++) {
    final file = SourceFile.fromString(text, url: 'foo.dart');
    if (file.lines != 301) {
      // ignore: only_throw_errors
      throw 'Length is wrong: ${file.lines}!';
    }
  }
  print('${stopwatch.elapsed}');
}
