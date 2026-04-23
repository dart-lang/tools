// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:cli_util/src/windows/win32_stdin.dart';
import 'package:test/test.dart';

void main() {
  test('Win32AnsiStdin translates windows stdin events to ansi escape codes',
      () async {
    assert(Platform.isWindows, 'This test only runs on Windows.');

    final process = await Process.start(
      Platform.resolvedExecutable,
      ['test/bin/echo_stdin.dart'],
    );

    final lines = StreamQueue(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()));

    // Wait for the child to be ready.
    expect(await lines.next, 'READY');

    // Test a regular character 'a' (ASCII 97).
    process.stdin.add([97]);
    expect(await lines.next, jsonEncode([97]));

    // Test special virtual key codes.
    process.stdin.add([VirtualKeyCodes.up]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x41]));
    process.stdin.add([VirtualKeyCodes.down]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x42]));
    process.stdin.add([VirtualKeyCodes.home]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x48]));
    process.stdin.add([VirtualKeyCodes.end]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x46]));
    process.stdin.add([VirtualKeyCodes.pageUp]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x35, 0x7e]));
    process.stdin.add([VirtualKeyCodes.pageDown]);
    expect(await lines.next, jsonEncode([0x1b, 0x5b, 0x36, 0x7e]));
    process.stdin.add([VirtualKeyCodes.enter]);
    expect(await lines.next, jsonEncode([0x0d]));
    process.stdin.add([VirtualKeyCodes.escape]);
    expect(await lines.next, jsonEncode([0x1b]));

    process.kill();
    await process.exitCode;
  });
}
