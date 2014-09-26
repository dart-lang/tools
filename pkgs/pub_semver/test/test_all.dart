// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pub_semver.test.test_all;

import 'package:unittest/unittest.dart';

import 'version_constraint_test.dart' as version_constraint_test;
import 'version_range_test.dart' as version_range_test;
import 'version_test.dart' as version_test;

main() {
  group('Version', version_test.main);
  group('VersionConstraint', version_constraint_test.main);
  group('VersionRange', version_range_test.main);
}
