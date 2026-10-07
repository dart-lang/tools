// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:boring/bindings.dart' as ssl;
import 'package:ffi/ffi.dart';

void main() {
  final digest = using((arena) {
    final input = utf8.encode('hello world');
    final data = arena<ffi.Uint8>(input.length);
    data.asTypedList(input.length).setAll(0, input);
    final md = ssl.EVP_sha256();
    final out = arena<ffi.Uint8>(ssl.EVP_MD_size(md));
    final outLen = arena<ffi.UnsignedInt>();

    final result = ssl.EVP_Digest(
      data.cast(),
      input.length,
      out,
      outLen,
      md,
      ffi.nullptr,
    );
    if (result != 1) {
      ssl.ERR_clear_error();
      throw StateError('SHA-256 failed');
    }
    return Uint8List.fromList(out.asTypedList(outLen.value));
  });

  final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  print('SHA-256("hello world"): $hex');
}
