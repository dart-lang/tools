// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

/// This file is not intended to be run directly, but is run by
/// `hierarchy_test.dart`.
void main() {
  defineReflectiveTests(SimpleTest); // Ungrouped tests
  defineReflectiveSuite(() {
    defineReflectiveSuite(() {
      defineReflectiveSuite(
        () {
          defineReflectiveTests(SimpleTest);
        }, /* unnamed */
      );
    }, name: 'level_2.1');
    defineReflectiveSuite(() {
      defineReflectiveTests(SimpleTest);
    }, name: 'level_2.2');
  }, name: 'level_1.1');
}

@reflectiveTest
class SimpleTest {
  // ignore: non_constant_identifier_names
  void test_foo() {
    expect(1, 1);
  }
}
