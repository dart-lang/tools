// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/io.dart';
import 'package:test/test.dart';

void main() {
  test('ExitCode.toString', () {
    expect('${ExitCode.success}', 'success: 0');
  });

  // Previously ExitCode was not an enum, but now it is.
  test('ExitCode is an enum', () {
    expect(ExitCode.success, isA<Enum>());
  });
}
