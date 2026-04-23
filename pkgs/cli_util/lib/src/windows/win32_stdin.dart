// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

/// Handles Win32 keyboard input and translates it to ANSI escape sequences.
///
/// **Note**: This is not a complete implementation and is only intended for
/// use with the provided cli components from this package.
///
/// This is used on Windows to work around issues where [stdin] doesn't forward
/// arrow keys or other special keys at all.
class Win32AnsiStdin extends Stream<List<int>> {
  static Win32AnsiStdin? _instance;

  final int _inputHandle;
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  bool _running = false;

  factory Win32AnsiStdin() => _instance ??= Win32AnsiStdin._create();

  Win32AnsiStdin._create()
    : _inputHandle = Win32Console.instance.getStdHandle(_stdInputHandle) {
    _controller.onCancel = _close;
  }

  void _startEventLoop() {
    if (_running) return;
    _running = true;
    _eventLoop();
  }

  Future<void> _eventLoop() async {
    // Allocate a buffer for up to 10 events at a time.
    final pInputRecord = calloc<InputRecord>(10);
    final pEventsRead = calloc<Uint32>();
    final pNumEvents = calloc<Uint32>();

    try {
      while (_running) {
        // Yield to Dart event loop between emitting events.
        await Future<void>.value();

        if (!_running) break;

        // Check how many events are available, we don't want to block
        // waiting to read events if there are none.
        final numEventsResult = Win32Console.instance
            .getNumberOfConsoleInputEvents(_inputHandle, pNumEvents);

        if (numEventsResult == 0 || pNumEvents.value == 0) {
          // Error reading events or no events available, yield and try again.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          continue;
        }

        // Read up to 10 events at a time.
        final eventsToRead = pNumEvents.value > 10 ? 10 : pNumEvents.value;
        final result = Win32Console.instance.readConsoleInputW(
          _inputHandle,
          pInputRecord,
          eventsToRead,
          pEventsRead,
        );

        if (result != 0 && pEventsRead.value > 0) {
          for (var i = 0; i < pEventsRead.value; i++) {
            final event = (pInputRecord + i).ref;
            if (event.eventType == InputRecordEventType.keyEvent) {
              final keyEvent = event.event.keyEvent;
              if (keyEvent.bKeyDown != 0) {
                final ansiiBytes = _translateKeyEvent(keyEvent);
                if (ansiiBytes != null && ansiiBytes.isNotEmpty) {
                  _controller.add(ansiiBytes);
                }
              }
            }
          }
        }
      }
    } finally {
      calloc.free(pInputRecord);
      calloc.free(pEventsRead);
      calloc.free(pNumEvents);
    }
  }

  /// Translate a win32 key event to ANSI escape sequences or characters.
  ///
  /// Returns `null` if this isn't an event we care about.
  List<int>? _translateKeyEvent(KeyEventRecord keyEvent) {
    final virtualKeyCode = keyEvent.wVirtualKeyCode;

    switch (virtualKeyCode) {
      case VirtualKeyCodes.up:
        return [0x1b, 0x5b, 0x41]; // ESC [ A
      case VirtualKeyCodes.down:
        return [0x1b, 0x5b, 0x42]; // ESC [ B
      case VirtualKeyCodes.home:
        return [0x1b, 0x5b, 0x48]; // ESC [ H
      case VirtualKeyCodes.end:
        return [0x1b, 0x5b, 0x46]; // ESC [ F
      case VirtualKeyCodes.pageUp:
        return [0x1b, 0x5b, 0x35, 0x7e]; // ESC [ 5 ~
      case VirtualKeyCodes.pageDown:
        return [0x1b, 0x5b, 0x36, 0x7e]; // ESC [ 6 ~
      case VirtualKeyCodes.enter:
        return [0x0d]; // CR
      case VirtualKeyCodes.escape:
        return [0x1b]; // ESC
    }

    final char = keyEvent.uChar;

    // Regular printable characters, just forward these along.
    if (char >= 32 && char < 127) return [char];

    return null;
  }

  Future<void> _close() async {
    _running = false;
    await _controller.close();
    _instance = null;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _startEventLoop();
    return _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// Windows API Constants
const int _stdInputHandle = -10;

// Virtual key codes
@visibleForTesting
extension VirtualKeyCodes on int {
  static const int enter = 0x0D;
  static const int escape = 0x1B;
  static const int pageUp = 0x21;
  static const int pageDown = 0x22;
  static const int end = 0x23;
  static const int home = 0x24;
  static const int up = 0x26;
  static const int down = 0x28;
}

/// Dart enum representing possible event types from input records.
///
/// https://learn.microsoft.com/en-us/windows/console/input-record-str
enum InputRecordEventType {
  keyEvent,
  mouseEvent,
  windowBufferSizeEvent,
  menuEvent,
  focusEvent,
  unknown;

  /// https://learn.microsoft.com/en-us/windows/console/input-record-str#members
  factory InputRecordEventType.fromInt(int value) => switch (value) {
    0x0001 => keyEvent,
    0x0002 => mouseEvent,
    0x0004 => windowBufferSizeEvent,
    0x0008 => menuEvent,
    0x0010 => focusEvent,
    _ => unknown,
  };
}

/// Windows console input record struct.
///
/// https://learn.microsoft.com/en-us/windows/console/input-record-str
@visibleForTesting
final class InputRecord extends Struct {
  @Uint16()
  external int _eventType;
  external EventUnion event;

  /// Converts [_eventType] to an [InputRecordEventType].
  InputRecordEventType get eventType =>
      InputRecordEventType.fromInt(_eventType);

  set eventType(InputRecordEventType type) {
    _eventType = switch (type) {
      InputRecordEventType.keyEvent => 0x0001,
      InputRecordEventType.mouseEvent => 0x0002,
      InputRecordEventType.windowBufferSizeEvent => 0x0004,
      InputRecordEventType.menuEvent => 0x0008,
      InputRecordEventType.focusEvent => 0x0010,
      InputRecordEventType.unknown => 0,
    };
  }
}

/// Union of event types for [InputRecord].
///
/// https://learn.microsoft.com/en-us/windows/console/input-record-str
@visibleForTesting
final class EventUnion extends Union {
  /// Maps to [InputRecord.eventType == 1].
  external KeyEventRecord keyEvent;
}

/// Windows key event record struct.
///
/// https://learn.microsoft.com/en-us/windows/console/key-event-record-str
@visibleForTesting
final class KeyEventRecord extends Struct {
  @Int32()
  external int bKeyDown;
  @Uint16()
  external int wRepeatCount;
  @Uint16()
  external int wVirtualKeyCode;
  @Uint16()
  external int wVirtualScanCode;
  @Uint16()
  external int uChar;
  @Uint32()
  external int dwControlKeyState;
}

/// FFI Function binding to
/// https://learn.microsoft.com/en-us/windows/console/getstdhandle
typedef GetStdHandleDart = int Function(int nStdHandle);

/// FFI Function binding to
/// https://learn.microsoft.com/en-us/windows/console/readconsoleinput
typedef ReadConsoleInputDart =
    int Function(
      int hConsoleInput,
      Pointer<InputRecord> lpBuffer,
      int nLength,
      Pointer<Uint32> lpNumberOfEventsRead,
    );

/// FFI Function binding to
/// https://learn.microsoft.com/en-us/windows/console/getnumberofconsoleinputevents
typedef GetNumberOfConsoleInputEventsDart =
    int Function(int hConsoleInput, Pointer<Uint32> lpcNumberOfEvents);

/// Lazy loader for Win32 console APIs.
@visibleForTesting
class Win32Console {
  static Win32Console? _instance;
  static Win32Console get instance {
    // Tests may set a mock instance on non-windows.
    if (_instance case final instance?) return instance;

    if (!Platform.isWindows) {
      throw StateError('Win32Console is only available on Windows');
    }
    return _instance = Win32Console._();
  }

  @visibleForTesting
  static set instance(Win32Console? value) => _instance = value;

  final GetStdHandleDart getStdHandle;
  final ReadConsoleInputDart readConsoleInputW;
  final GetNumberOfConsoleInputEventsDart getNumberOfConsoleInputEvents;

  factory Win32Console._() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    return Win32Console.internal(
      kernel32.lookupFunction<IntPtr Function(Uint32), GetStdHandleDart>(
        'GetStdHandle',
      ),
      kernel32.lookupFunction<
        Int32 Function(IntPtr, Pointer<InputRecord>, Uint32, Pointer<Uint32>),
        ReadConsoleInputDart
      >('ReadConsoleInputW'),
      kernel32.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        GetNumberOfConsoleInputEventsDart
      >('GetNumberOfConsoleInputEvents'),
    );
  }

  @visibleForTesting
  Win32Console.internal(
    this.getStdHandle,
    this.readConsoleInputW,
    this.getNumberOfConsoleInputEvents,
  );
}
