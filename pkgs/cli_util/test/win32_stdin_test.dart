// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';

import 'package:async/async.dart';
import 'package:cli_util/src/windows/win32_stdin.dart';
import 'package:test/test.dart';

void main() {
  late MockWin32Console mockConsole;

  setUp(() {
    mockConsole = MockWin32Console();
    Win32Console.instance = mockConsole;
  });

  tearDown(() {
    Win32Console.instance = null;
  });
  
  test('Win32AnsiStdin translates windows stdin events to ansi escape codes',
      () async {
    final stdin = Win32AnsiStdin();
    final queue = StreamQueue(stdin);

    // Test a regular character 'a' (ASCII 97).
    await mockConsole.pushEvent(97);
    expect(await queue.next, [97]);

    // Test special virtual key codes.
    await mockConsole.pushEvent(VirtualKeyCodes.up);
    expect(await queue.next, [0x1b, 0x5b, 0x41]);

    await mockConsole.pushEvent(VirtualKeyCodes.down);
    expect(await queue.next, [0x1b, 0x5b, 0x42]);

    await mockConsole.pushEvent(VirtualKeyCodes.home);
    expect(await queue.next, [0x1b, 0x5b, 0x48]);

    await mockConsole.pushEvent(VirtualKeyCodes.end);
    expect(await queue.next, [0x1b, 0x5b, 0x46]);

    await mockConsole.pushEvent(VirtualKeyCodes.pageUp);
    expect(await queue.next, [0x1b, 0x5b, 0x35, 0x7e]);

    await mockConsole.pushEvent(VirtualKeyCodes.pageDown);
    expect(await queue.next, [0x1b, 0x5b, 0x36, 0x7e]);

    await mockConsole.pushEvent(VirtualKeyCodes.enter);
    expect(await queue.next, [0x0d]);

    await mockConsole.pushEvent(VirtualKeyCodes.escape);
    expect(await queue.next, [0x1b]);

    await queue.cancel();
  });
}

class MockWin32Console extends Win32Console {
  final List<int> _mockEvents;

  factory MockWin32Console() => MockWin32Console._([]);

  MockWin32Console._(List<int> mockEvents)
      : _mockEvents = mockEvents,
        super.internal(
          (nStdHandle) => 123,
          (hConsoleInput, lpBuffer, nLength, lpNumberOfEventsRead) {
            final count =
                nLength < mockEvents.length ? nLength : mockEvents.length;
            for (var i = 0; i < count; i++) {
              final keyCode = mockEvents.removeAt(0);
              final record = (lpBuffer + i).ref;
              record.eventType = InputRecordEventType.keyEvent;
              record.event.keyEvent.bKeyDown = 1;
              record.event.keyEvent.wVirtualKeyCode = keyCode;
              record.event.keyEvent.uChar = 0;
              if (keyCode >= 32 && keyCode < 127) {
                record.event.keyEvent.uChar = keyCode;
              }
            }
            lpNumberOfEventsRead.value = count;
            return 1;
          },
          (hConsoleInput, lpcNumberOfEvents) {
            lpcNumberOfEvents.value = mockEvents.length;
            return 1;
          },
        );

  Future<void> pushEvent(int keyCode) async {
    _mockEvents.add(keyCode);
    // Yield to allow the event loop in Win32AnsiStdin to run.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
