// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show base64Url;
import 'dart:math' show Random;

const _idByteLength = 24;
const _maxByteValue = 256;

final _secureRandom = Random.secure();

/// Generates a URL-safe cryptographically random ID string with 192 bits of
/// entropy.
String generateId() => base64Url.encode(
  List<int>.generate(
    _idByteLength,
    (_) => _secureRandom.nextInt(_maxByteValue),
  ),
);
