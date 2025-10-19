// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:coverage/src/coverage_options.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final baseTestPath = 'test/test_file_locator';
  late Directory testDirectory;

  test('options file exists', () {
    testDirectory = Directory('$baseTestPath/pkg1/lib/src');
    var filePath =
        CoverageOptionsProvider.findOptionsFilePath(directory: testDirectory);
    expect(path.normalize('$baseTestPath/pkg1/coverage_options.yaml'),
        path.normalize(filePath!));

    testDirectory = Directory('$baseTestPath/pkg1/lib');
    filePath =
        CoverageOptionsProvider.findOptionsFilePath(directory: testDirectory);
    expect(path.normalize('$baseTestPath/pkg1/coverage_options.yaml'),
        path.normalize(filePath!));
  });

  test('options file missing', () {
    testDirectory = Directory('$baseTestPath/pkg2/lib/src');
    var filePath =
        CoverageOptionsProvider.findOptionsFilePath(directory: testDirectory);
    expect(filePath, isNull);

    testDirectory = Directory('$baseTestPath/pkg2/lib');
    filePath =
        CoverageOptionsProvider.findOptionsFilePath(directory: testDirectory);
    expect(filePath, isNull);
  });

  test('no pubspec found', () {
    var filePath = CoverageOptionsProvider.findOptionsFilePath(
        directory: Directory.systemTemp);
    expect(filePath, isNull);

    filePath = CoverageOptionsProvider.findOptionsFilePath(
        directory: Directory.systemTemp);
    expect(filePath, isNull);
  });
}
