// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Checks that the dynamic library bundled for `dart test` defines every bound
// function, so that none of them fails to resolve when called.
@TestOn('linux || mac-os || windows')
library;

import 'dart:ffi';
import 'dart:io';

import 'package:boring/bindings.dart' as ssl;
import 'package:boring/src/bindings/record_use_mapping.g.dart';
import 'package:code_assets/code_assets.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

/// The bound functions that BoringSSL doesn't compile for Windows.
const _notOnWindows = {
  'bssl_dart_RAND_disable_fork_unsafe_buffering',
  'bssl_dart_RAND_enable_fork_unsafe_buffering',
};

void main() {
  test('the library defines every bound function', () {
    final library = _loadedLibrary();
    final missing = [
      for (final symbol in recordUseMapping.values)
        if (!library.providesSymbol(symbol)) symbol,
    ];
    expect(
      missing,
      Platform.isWindows ? unorderedEquals(_notOnWindows) : isEmpty,
    );
  });
}

/// The dynamic library that the bindings resolve their symbols in.
DynamicLibrary _loadedLibrary() {
  // Resolving a symbol loads the library.
  final address = ssl.addresses.OPENSSL_free;
  if (Platform.isWindows) {
    // Windows returns the loaded module with this name.
    return DynamicLibrary.open(OS.windows.dylibFileName('bssl_dart'));
  }
  return using((arena) {
    final info = arena<_DlInfo>();
    if (_dladdr(address.cast<Void>(), info) == 0) {
      throw StateError('dladdr failed');
    }
    return DynamicLibrary.open(info.ref.fileName.toDartString());
  });
}

/// `Dl_info` from `<dlfcn.h>`.
final class _DlInfo extends Struct {
  external Pointer<Utf8> fileName;
  external Pointer<Void> baseAddress;
  external Pointer<Utf8> symbolName;
  external Pointer<Void> symbolAddress;
}

final _dladdr = DynamicLibrary.process()
    .lookupFunction<
      Int Function(Pointer<Void>, Pointer<_DlInfo>),
      int Function(Pointer<Void>, Pointer<_DlInfo>)
    >('dladdr');
