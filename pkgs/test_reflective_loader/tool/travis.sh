#!/bin/bash

# Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.   
set -e

# Verify that the libraries are error free.
dartanalyzer --fatal-warnings \
  lib/test_reflective_loader.dart \
  test/test_reflective_loader_test.dart

# Run the tests.
dart test/test_reflective_loader_test.dart
