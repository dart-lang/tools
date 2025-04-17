// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' show Random;

/// Generates a pseudo-random ID string with 32 bits of entropy.
String generateId() {
  final chars = List<int>.filled(6, 0);
  final random = Random();
  var bits = random.nextInt(0x100000000);
  for (var i = 0; i < 6; i++) {
    chars[i] = _base64Chars.codeUnitAt(bits & 0x3F);
    bits >>>= 6;
  }
  return String.fromCharCodes(chars);
}

// A standard encoding of 6 bits per character, without any non-ASCII,
// non-printable or disallowed characters.
const _base64Chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
