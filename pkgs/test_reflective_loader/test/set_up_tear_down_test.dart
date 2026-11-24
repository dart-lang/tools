// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('includes setUp and tearDown results only when defined', () async {
    var (:stdout, :stderr) =
        await runTestFile('set_up_tear_down_test.data.dart');

    expect(stderr, isEmpty);
    expect(
        stdout,
        allOf([
          contains('WithSetUpTearDownTest (setUpAll)'),
          contains('WithSetUpTearDownTest test_pass'),
          contains('WithSetUpTearDownTest (tearDownAll)'),
          contains('NoSetUpTearDownTest test_pass'),
          contains('All tests passed!'),
        ]));
  });
}
