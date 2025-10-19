// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    // ensure set-ups and tear-downs are not prematurely called ie before any
    // tests actually execute
    setUpAll(() {
      expect(TestReflectiveLoaderTest.didSetUpClass, false);
      expect(TestReflectiveLoaderTest.didTearDownClass, false);
      expect(SecondTest.didSetUpClass, false);
      expect(SecondTest.didTearDownClass, false);
    });
    defineReflectiveTests(TestReflectiveLoaderTest);
    defineReflectiveTests(SecondTest);
    tearDownAll(() {
      expect(TestReflectiveLoaderTest.didSetUpClass, true);
      expect(TestReflectiveLoaderTest.didTearDownClass, true);
      expect(SecondTest.didSetUpClass, true);
      expect(SecondTest.didTearDownClass, true);
    });
  });
}

@reflectiveTest
class TestReflectiveLoaderTest {
  static bool didSetUpClass = false;
  static bool didTearDownClass = false;

  // TODO(scheglov): Linter was updated to automatically ignore
  // this but needs time before it is actually used. Remove this
  // ignore and others like it in this file once the linter
  // change is active in this project:
  // ignore: unreachable_from_main
  static void setUpClass() {
    expect(didSetUpClass, false);
    didSetUpClass = true;
    expect(didTearDownClass, false);
  }

  // TODO(scheglov): See comment directly above
  // "TestReflectiveLoaderTest.setUpClass" for info about this ignore:
  // ignore: unreachable_from_main
  static void tearDownClass() {
    expect(didSetUpClass, true);
    expect(didTearDownClass, false);
    didTearDownClass = true;
  }

  void test_classwide_state() {
    expect(didSetUpClass, true);
    expect(didTearDownClass, false);
  }

  @failingTest
  void test_fails() {
    expect(false, true);
  }

  @skippedTest
  void test_fails_but_skipped() {
    throw StateError('foo');
  }

  @failingTest
  Future test_fails_throws_async() {
    return Future.error('foo');
  }

  @failingTest
  void test_fails_throws_sync() {
    throw StateError('foo');
  }

  void test_passes() {
    expect(true, true);
  }

  @skippedTest
  void test_times_out_but_skipped() {
    while (true) {}
  }
}

@reflectiveTest
class SecondTest {
  static bool didSetUpClass = false;
  static bool didTearDownClass = false;

  // TODO(scheglov): See comment directly above
  // "TestReflectiveLoaderTest.setUpClass" for info about this ignore:
  // ignore: unreachable_from_main
  static void setUpClass() {
    expect(didSetUpClass, false);
    didSetUpClass = true;
    expect(didTearDownClass, false);
  }

  // TODO(scheglov): See comment directly above
  // "TestReflectiveLoaderTest.setUpClass" for info about this ignore:
  // ignore: unreachable_from_main
  static void tearDownClass() {
    expect(didSetUpClass, true);
    expect(didTearDownClass, false);
    didTearDownClass = true;
  }

  void test_classwide_state() {
    expect(didSetUpClass, true);
    expect(didTearDownClass, false);
  }
}
