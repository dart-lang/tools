// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

Future<({String stdout, String stderr})> runTestFile(String filename,
    [List<String> args = const []]) async {
  var testPackagePath = (await Isolate.resolvePackageUri(
          Uri.parse('package:test_reflective_loader/')))!
      .toFilePath();
  var testFilePath = path.isAbsolute(filename)
      ? filename
      : path.normalize(path.join(testPackagePath, '..', 'test', filename));
  var result = await Process.run(Platform.resolvedExecutable, [
    'test',
    // Force the expanded reporter because otherwise the test output will
    // differ slightly when the tests run on GitHub (it uses a GitHub
    // reporter).
    '-r', 'expanded',
    ...args,
    testFilePath
  ]);

  var output = result.stdout.toString().trim();
  var error = result.stderr.toString().trim();

  return (stdout: output, stderr: error);
}
