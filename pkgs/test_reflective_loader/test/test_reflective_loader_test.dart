// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TestReflectiveLoaderTest);
  });
}

@reflectiveTest
class TestReflectiveLoaderTest {
  void test_passes() {
    expect(true, true);
  }

  @failingTest
  void test_fails() {
    expect(false, true);
  }

  @failingTest
  void test_fails_throws_sync() {
    throw 'foo';
  }

  @failingTest
  Future test_fails_throws_async() {
    return new Future.error('foo');
  }

  @skippedTest
  void test_fails_but_skipped() {
    throw 'foo';
  }

  @skippedTest
  void test_times_out_but_skipped() {
    while (true) {}
  }
}
