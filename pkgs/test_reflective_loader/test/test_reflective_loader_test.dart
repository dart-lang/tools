// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

// ignore_for_file: always_declare_return_types

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TestReflectiveLoaderTest);
  });
}

@reflectiveTest
class TestReflectiveLoaderTest {
  String pathname;

  test_passes() {
    expect(true, true);
  }

  @failingTest
  test_fails() {
    expect(false, true);
  }

  @failingTest
  test_fails_throws_sync() {
    throw 'foo';
  }

  @failingTest
  test_fails_throws_async() {
    return new Future.error('foo');
  }
}
