// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

void main() {
  test('an alias to a large shared structure loads quickly as a mapping key',
      () async {
    // The key expands to 8^12 scalars, too many to walk one by one.
    final yaml = cleanUpLiteral('''
        a0: &a0 [x, x, x, x, x, x, x, x]
        a1: &a1 [*a0, *a0, *a0, *a0, *a0, *a0, *a0, *a0]
        a2: &a2 [*a1, *a1, *a1, *a1, *a1, *a1, *a1, *a1]
        a3: &a3 [*a2, *a2, *a2, *a2, *a2, *a2, *a2, *a2]
        a4: &a4 [*a3, *a3, *a3, *a3, *a3, *a3, *a3, *a3]
        a5: &a5 [*a4, *a4, *a4, *a4, *a4, *a4, *a4, *a4]
        a6: &a6 [*a5, *a5, *a5, *a5, *a5, *a5, *a5, *a5]
        a7: &a7 [*a6, *a6, *a6, *a6, *a6, *a6, *a6, *a6]
        a8: &a8 [*a7, *a7, *a7, *a7, *a7, *a7, *a7, *a7]
        a9: &a9 [*a8, *a8, *a8, *a8, *a8, *a8, *a8, *a8]
        a10: &a10 [*a9, *a9, *a9, *a9, *a9, *a9, *a9, *a9]
        a11: &a11 [*a10, *a10, *a10, *a10, *a10, *a10, *a10, *a10]
        ? *a11
        : v''');
    // loadYaml is synchronous, so a test timeout can't stop it. Load in an
    // isolate that is killed if it takes too long.
    final results = ReceivePort();
    final isolate = await Isolate.spawn(_loadKey, (results.sendPort, yaml),
        onError: results.sendPort, onExit: results.sendPort);
    try {
      final result = await results.first.timeout(const Duration(seconds: 10));
      expect(result, isTrue, reason: 'Loading failed: $result');
    } on TimeoutException {
      fail('Loading took more than 10 seconds.');
    } finally {
      isolate.kill(priority: Isolate.immediate);
      results.close();
    }
  });
}

/// Loads [args].$2 and sends whether its last key is the `a11` anchor.
///
/// Looking up the key would compare it with deepEquals, which walks the whole
/// expansion, so the key is checked by identity.
void _loadKey((SendPort, String) args) {
  final (sendPort, yaml) = args;
  final doc = loadYaml(yaml) as Map;
  sendPort.send(identical(doc.keys.last, doc['a11']));
}
