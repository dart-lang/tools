// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

/// This file is not intended to be run directly, but is run by
/// `set_up_tear_down_test.dart`.
void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WithSetUpTearDownTest);
    defineReflectiveTests(NoSetUpTearDownTest);
  });
}

@reflectiveTest
class NoSetUpTearDownTest {
  void test_pass() {
    expect(1, 1);
  }
}

@reflectiveTest
class WithSetUpTearDownTest {
  static void setUpClass() {}
  static void tearDownClass() {}

  void test_pass() {
    expect(1, 1);
  }
}
