// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('builds the correct hierarchy of group names / test names', () async {
    var (:stdout, :stderr) = await runTestFile('hierarchy_test.data.dart');

    expect(stderr, isEmpty);
    expect(
        stdout,
        allOf([
          contains('SimpleTest test_foo'),
          contains('level_1.1 level_2.1 SimpleTest test_foo'),
          contains('level_1.1 level_2.2 SimpleTest test_foo'),
          contains('All tests passed!'),
        ]));
  });
}
