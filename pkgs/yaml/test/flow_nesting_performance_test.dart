// Copyright (c) 2026, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('scanning time does not grow with flow nesting depth', () {
    // The same scalars at depth 1 and at depth 1000. Before the fix the
    // scanner walked every open flow level for each token, so the deep
    // document took about 30 times longer than the shallow one.
    const items = 200000;
    String document(int depth) =>
        '${'[' * depth}${List.filled(items, '1').join(',')}${']' * depth}';
    int millisecondsToLoad(String text) {
      final stopwatch = Stopwatch()..start();
      loadYaml(text);
      return stopwatch.elapsedMilliseconds;
    }

    final shallow = document(1);
    final deep = document(1000);
    // Warm up the JIT so that both measurements run optimized code.
    millisecondsToLoad(shallow);
    millisecondsToLoad(deep);

    expect(
      millisecondsToLoad(deep),
      lessThan(millisecondsToLoad(shallow) * 5 + 100),
    );
  });
}
