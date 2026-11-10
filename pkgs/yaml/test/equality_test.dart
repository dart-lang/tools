// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/src/equality.dart';

/// A leaf value that counts how many times its hash code is read.
class _CountingLeaf {
  int reads = 0;

  @override
  int get hashCode {
    reads++;
    return 7;
  }

  @override
  bool operator ==(Object other) => other is _CountingLeaf;
}

void main() {
  group('deepHashCode', () {
    test('hashes a node shared many times only once', () {
      final leaf = _CountingLeaf();
      // Each level holds the level below twice, so the fully expanded
      // structure has 2^20 leaves but only 21 distinct nodes.
      Object node = leaf;
      for (var i = 0; i < 20; i++) {
        node = [node, node];
      }
      deepHashCode(node);
      // Only lists are cached, so the innermost list reads both of its leaves.
      expect(leaf.reads, 2);
    });

    test('gives shared and unshared copies of a structure the same hash', () {
      List<Object?> build({required bool share}) {
        Object? node = {
          'a': 1,
          'b': ['x', 2.5]
        };
        for (var i = 0; i < 5; i++) {
          node = share ? [node, node] : [node, deepCopy(node)];
        }
        return node as List<Object?>;
      }

      expect(
          deepHashCode(build(share: true)), deepHashCode(build(share: false)));
    });

    test('gives equal self-referential structures the same hash', () {
      List<Object?> loop() {
        final inner = <Object?>['a'];
        final outer = <Object?>[inner, inner];
        inner.add(outer);
        return outer;
      }

      final first = loop();
      final second = loop();
      expect(deepEquals(first, second), isTrue);
      expect(deepHashCode(first), deepHashCode(second));
    });

    test('hashes a node in a loop the same however the node is reached', () {
      // `b` and `c` refer to each other. Hashing `[b, c]` reaches `c` first
      // from inside `b`, where the loop back to `b` ends the walk, then from
      // the top, where the walk goes on into `b`. `[b, c2]`, with `c2` an
      // unshared copy of `c`, is equal, so it must hash the same.
      (List<Object?>, List<Object?>) pair() {
        final b = <Object?>['x', 'x'];
        final c = <Object?>['x', b];
        b.add(c);
        return (b, c);
      }

      final (b, c) = pair();
      final (_, c2) = pair();
      final shared = [b, c, 'x'];
      final unshared = [b, c2, 'x'];
      expect(deepEquals(shared, unshared), isTrue);
      expect(deepHashCode(shared), deepHashCode(unshared));
    });

    test('keeps caching shared nodes next to a loop', () {
      final leaf = _CountingLeaf();
      Object node = leaf;
      for (var i = 0; i < 20; i++) {
        node = [node, node];
      }
      final loop = <Object?>[];
      loop.add(loop);
      deepHashCode([loop, node]);
      // Only lists are cached, so the innermost list reads both of its leaves.
      expect(leaf.reads, 2);
    });
  });
}

Object? deepCopy(Object? value) => switch (value) {
      Map() => {
          for (final MapEntry(:key, :value) in value.entries)
            deepCopy(key): deepCopy(value)
        },
      List() => [for (final e in value) deepCopy(e)],
      _ => value,
    };
