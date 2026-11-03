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
  const items = 100000;

  /// The fastest of a few loads, which is not thrown off by a GC pause or a
  /// busy machine, after a warm-up load so the JIT has optimized the scanner.
  int millisecondsToLoad(String text) {
    loadYaml(text);
    var fastest = 1 << 30;
    for (var i = 0; i < 3; i++) {
      final stopwatch = Stopwatch()..start();
      loadYaml(text);
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < fastest) fastest = elapsed;
    }
    return fastest;
  }

  // Before the fix the scanner walked every open flow level for each token, so
  // the document nested 1000 levels deep took about 6 times longer to scan
  // than the same scalars at depth 1; now the two take about the same time.
  void expectDepthDoesNotMatter(String Function(int depth) document) {
    final shallow = millisecondsToLoad(document(1));
    final deep = millisecondsToLoad(document(1000));
    expect(deep, lessThan(shallow * 3 + 50));
  }

  test('scanning flow sequences does not depend on nesting depth', () {
    final scalars = List.filled(items, '1').join(',');
    expectDepthDoesNotMatter(
      (depth) => '${'[' * depth}$scalars${']' * depth}',
    );
  });

  test('scanning flow mapping values does not depend on nesting depth', () {
    final pairs = List.generate(items, (i) => 'k$i: 1').join(',');
    expectDepthDoesNotMatter(
      (depth) => '${'{a: ' * depth}{$pairs}${'}' * depth}',
    );
  });

  test('nested flow collections still load as the same structure', () {
    expect(loadYaml('[[a, {b: [c]}], {d: [e, f]}]'), [
      [
        'a',
        {
          'b': ['c']
        }
      ],
      {
        'd': ['e', 'f']
      },
    ]);
  });
}
