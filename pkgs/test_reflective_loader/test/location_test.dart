// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test("reports correct locations in the JSON output from 'dart test'",
      () async {
    var testPackagePath = (await Isolate.resolvePackageUri(
            Uri.parse('package:test_reflective_loader/')))!
        .toFilePath();
    var testFilePath = path.normalize(path.join(
        testPackagePath, '..', 'test', 'test_reflective_loader_test.dart'));
    var testFileContent = File(testFilePath).readAsLinesSync();

    var (:stdout, :stderr) = await runTestFile(testFilePath, reporter: 'json');

    expect(stderr, isEmpty);
    expect(stdout, isNotEmpty);

    for (var event in LineSplitter.split(stdout).map(jsonDecode)) {
      if (event case {'type': 'testStart', 'test': Map<String, Object?> test}) {
        var name = test['name'] as String;

        // Skip the "loading" test, it never has a location.
        if (name.startsWith('loading')) {
          continue;
        }

        // Split just the method name from the combined test so we can search
        // the source code to ensure the locations match up.
        name = name.split(' ').last.trim();

        // The test names "(setUpAll)" and "(tearDownAll)" can be calls to
        // setUpAll() and tearDownAll() or methods named "setUpClass" and
        // "tearDownClass" so just expect to find "setUp" or "tearDown" on lines
        // at the provided locations.
        if (name == '(setUpAll)') {
          name = 'setUp';
        } else if (name == '(tearDownAll)') {
          name = 'tearDown';
        }

        // Expect locations for all remaining fields.
        var url = test['url'] as String;
        var line = test['line'] as int;
        var column = test['column'] as int;

        expect(path.equals(Uri.parse(url).toFilePath(), testFilePath), isTrue);

        // Verify the location provided matches where this test appears in the
        // file.
        var lineContent = testFileContent[line - 1];
        // If the line is an annotation, skip to the next line
        if (lineContent.trim().startsWith('@')) {
          lineContent = testFileContent[line];
        }
        expect(lineContent, contains(name),
            reason: 'JSON reports test $name on line $line, '
                'but line content is "$lineContent"');

        // Verify the column too.
        var columnContent = lineContent.substring(column - 1);
        expect(columnContent, contains(name),
            reason: 'JSON reports test $name at column $column, '
                'but text at column is "$columnContent"');
      }
    }
  });
}
