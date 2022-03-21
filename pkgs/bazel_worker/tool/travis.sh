#!/bin/bash

# Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

dart pub get

# Verify that the libraries are error free.
dart analyze --fatal-infos \
  lib/bazel_worker.dart \
  lib/driver.dart \
  lib/testing.dart \
  test/test_all.dart

# Run the tests.
dart test

pushd e2e_test
dart pub get
dart analyze --fatal-infos test/e2e_test.dart
dart test
popd
