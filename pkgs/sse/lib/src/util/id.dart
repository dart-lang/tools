// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show base64Url;
import 'dart:math' show Random;

// 24 random bytes provide 192 bits of entropy against brute-force guessing of
// active `sseClientId` sessions (for example during `keepAlive` or
// `ignoreDisconnect` reconnection windows). Using a multiple of 3 bytes also
// ensures `base64Url.encode` produces 32 URL-safe characters with no `=`
// padding, so IDs can be interpolated directly into query strings.
const _idByteLength = 24;
const _maxByteValue = 256;

// Lazily initialized on first use. Uses the platform CSPRNG (including
// `crypto.getRandomValues` on web runtimes and Web Workers).
final _secureRandom = Random.secure();

/// Generates a 32-character URL-safe cryptographically random ID string with
/// 192 bits of entropy.
String generateId() => base64Url.encode(
  List<int>.generate(
    _idByteLength,
    (_) => _secureRandom.nextInt(_maxByteValue),
  ),
);
