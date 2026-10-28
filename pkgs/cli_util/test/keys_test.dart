// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cli_util/src/components/keys.dart';
import 'package:test/test.dart';

void main() {
  group('keys', () {
    // The keys stream doesn't close when its source does, so only take as
    // many keys as are expected.
    Future<List<Key>> keysFor(List<List<int>> chunks, int count) =>
        Stream.fromIterable(chunks).keys.take(count).toList();

    test('maps an escape sequence in a single chunk', () async {
      expect(
        await keysFor([
          [27, 91, 65],
        ], 1),
        [Key.up],
      );
    });

    test('maps an escape sequence split after "esc ["', () async {
      expect(
        await keysFor([
          [27, 91],
          [66],
        ], 1),
        [Key.down],
      );
    });

    test('keeps reading keys after a split escape sequence', () async {
      expect(
        await keysFor([
          [32, 27, 91],
          [65, 13],
        ], 3),
        [Key.space, Key.up, Key.enter],
      );
    });

    test('maps a lone escape to quit', () async {
      expect(
        await keysFor([
          [27],
        ], 1),
        [Key.quit],
      );
    });
  });
}
