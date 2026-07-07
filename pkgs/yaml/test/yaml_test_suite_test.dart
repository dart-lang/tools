// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'yaml_test_suite.dart';

void main() {
  final cases = loadYamlTestSuite();

  for (final c in cases) {
    test(c.name, () {
      if (_expectedFailures.contains(c.id)) {
        try {
          c.runTest();
        } on TestFailure {
          return; // Expected failure, exit the test successfully.
        } catch (e) {
          return; // Other errors from package:yaml are also expected failures.
        }
        fail(
          'Test ${c.id} was expected to fail, but it passed. '
          'Please remove it from _expectedFailures!',
        );
      } else {
        c.runTest();
      }
    });
  }
}

const _expectedFailures = <String>[
  'VJP3-0',
  '7FWL-0',
  '565N-0',
  '6CK3-0',
  'J7PZ-0',
  'UGM3-0',
  'X4QW-0',
  'CC74-0',
  'CVW2-0',
  'QB6E-0',
  'SU5Z-0',
  'DK4H-0',
  '5TYM-0',
  '9C9N-0',
  'LHL4-0',
  'ZXT5-0',
  'P76L-0',
  '9JBA-0',
  'S98Z-0',
  '2JQS-0',
  'MUS6-0',
  'MUS6-1',
  'BS4K-0',
  'X38W-0',
  'ZYU8-2',
  'RHX7-0',
  '2XXW-0',
  '9HCY-0',
  'KS4U-0',
  'Z9M4-0',
  'EB22-0',
  '3HFZ-0',
];
