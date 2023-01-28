// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library samples_test;

import 'dart:io';

import 'package:csslib/parser.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const testOptions = PreprocessorOptions(
  useColors: false,
  checked: false,
  warningsAsErrors: true,
  inputFile: 'memory',
);

void testCSSFile(File cssFile) {
  final errors = <Message>[];
  final css = cssFile.readAsStringSync();
  final stylesheet = parse(css, errors: errors, options: testOptions);

  expect(stylesheet, isNotNull);
  expect(errors, isEmpty, reason: errors.toString());
}

void main() async {
  // Iterate over all sub-folders of third_party,
  // and then all css files in those.
  final thirdParty = path.join(Directory.current.path, 'third_party');
  for (var entity in Directory(thirdParty).listSync()) {
    if (await FileSystemEntity.isDirectory(entity.path)) {
      for (var element in Directory(entity.path).listSync()) {
        if (element is File && element.uri.pathSegments.last.endsWith('.css')) {
          test(element.uri.pathSegments.last, () => testCSSFile(element));
        }
      }
    }
  }
}
