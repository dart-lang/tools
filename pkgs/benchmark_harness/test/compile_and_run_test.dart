// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:benchmark_harness/src/compile_and_run.dart';
import 'package:test/test.dart';

void main() {
  late final Directory tempDir;
  late final Uri testFilePath;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('benchtest_');
    testFilePath = tempDir.uri.resolve('input.dart');
    File.fromUri(testFilePath)
      ..create()
      ..writeAsStringSync(_testDartFile);
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  for (var bench in RuntimeFlavor.values) {
    test('$bench', () async {
      await bench.func(testFilePath.toFilePath());
    });
  }
}

const _testDartFile = '''
void main() {
  // outputs 0 is JS
  // 8589934592 everywhere else
  print(1 << 33);
}
''';
