// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Used by the `wind32_integration_test.ps1` script to verify that
/// `Win32AnsiStdin` works as expected on Windows powershell.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:cli_util/src/windows/win32_stdin.dart';
import 'package:ffi/ffi.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: echo_stdin.dart <output_file>');
    exit(1);
  }

  final filePath = args.first;
  final file = File(filePath);

  // Ensure file is cleared or created
  file.writeAsStringSync('');

  // Detach from current console and attach to parent console to ensure we can
  // read input in CI.
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final freeConsole = kernel32
        .lookupFunction<Int32 Function(), int Function()>('FreeConsole');
    final attachConsole = kernel32
        .lookupFunction<Int32 Function(Uint32), int Function(int)>(
          'AttachConsole',
        );

    freeConsole();
    attachConsole(0xFFFFFFFF); // ATTACH_PARENT_PROCESS
  } catch (e) {
    // Ignore errors
  }

  // Open CONIN$ to get a valid console handle, bypassing GetStdHandle which
  // might be redirected.
  var coninHandle = -1;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final createFileW = kernel32.lookupFunction<
      IntPtr Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer,
        Uint32,
        Uint32,
        IntPtr,
      ),
      int Function(Pointer<Utf16>, int, int, Pointer, int, int, int)
    >('CreateFileW');

    final coninPath = r'CONIN$'.toNativeUtf16();
    coninHandle = createFileW(
      coninPath,
      0x80000000 | 0x40000000, // GENERIC_READ | GENERIC_WRITE
      1, // FILE_SHARE_READ
      nullptr,
      3, // OPEN_EXISTING
      0,
      0,
    );

    calloc.free(coninPath);
  } catch (e) {
    // Ignore errors
  }

  final subscription = Win32AnsiStdin(
    coninHandle == -1 ? null : coninHandle,
  ).listen((data) {
    file.writeAsStringSync('${jsonEncode(data)}\r\n', mode: FileMode.append);
  });

  file.writeAsStringSync('READY\r\n', mode: FileMode.append);

  // Keep process alive to receive events.
  // It will be killed by the powershell script.
  await Future<void>.delayed(const Duration(seconds: 30));

  await subscription.cancel();
}
