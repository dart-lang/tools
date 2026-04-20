// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

/// Runs the test file at [filename] and returns its stdout and stderr.
///
/// [filename] can be a relative path from the `test/` directory, or an
/// absolute path.
///
/// Defaults to the expanded reporter (because the default reporter may differ
/// between GitHub and running locally) but this can be overridden with
/// [reporter].
Future<({String stdout, String stderr})> runTestFile(String filename,
    {String reporter = 'expanded'}) async {
  var testPackagePath = (await Isolate.resolvePackageUri(
          Uri.parse('package:test_reflective_loader/')))!
      .toFilePath();
  var testFilePath = path.isAbsolute(filename)
      ? filename
      : path.normalize(path.join(testPackagePath, '..', 'test', filename));
  var result = await Process.run(
      Platform.resolvedExecutable, ['test', '-r', reporter, testFilePath]);

  var output = result.stdout.toString().trim();
  var error = result.stderr.toString().trim();

  return (stdout: output, stderr: error);
}
