// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:unified_analytics/src/asserts.dart';

void main() {
  test('Failure if client_id top level key is missing', () {
    final Map<String, Object?> body = {};

    expect(() => checkBody(body), throwsA(isA<AssertionError>()));
  });
}
