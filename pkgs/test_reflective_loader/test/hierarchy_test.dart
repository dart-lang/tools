// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('builds the correct hierarchy of group names / test names', () async {
    var testPackagePath = (await Isolate.resolvePackageUri(
            Uri.parse('package:test_reflective_loader/')))!
        .toFilePath();
    var testFilePath = path.normalize(
        path.join(testPackagePath, '..', 'test', 'hierarchy_test.data.dart'));
    var result =
        await Process.run(Platform.resolvedExecutable, ['test', testFilePath]);

    var error = result.stderr.toString().trim();
    var output = result.stdout.toString().trim();

    expect(error, isEmpty);
    expect(
        output,
        allOf([
          contains('+0: SimpleTest test_foo'),
          contains('+1: level_1.1 level_2.1 SimpleTest test_foo'),
          contains('+2: level_1.1 level_2.2 SimpleTest test_foo'),
          contains('+3: All tests passed!'),
        ]));
  });
}
