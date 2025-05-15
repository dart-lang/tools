// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

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
    }, skip: _skipWasm(bench));
  }
}

// Can remove this once the min tested SDK on GitHub is >= 3.7
String? _skipWasm(RuntimeFlavor flavor) {
  if (flavor != RuntimeFlavor.wasm) {
    return null;
  }
  final versionBits = Platform.version.split('.');
  final versionValues = versionBits.take(2).map(int.parse).toList();

  return switch ((versionValues[0], versionValues[1])) {
    // If major is greater than 3, it's definitely >= 3.7
    (int m, _) when m > 3 => null,
    // If major is 3, check the minor version
    (3, int n) when n >= 7 => null,
    // All other cases (major < 3, or major is 3 but minor < 7)
    _ => 'Required Dart >= 3.7',
  };
}

const _testDartFile = '''
void main() {
  // outputs 0 is JS
  // 8589934592 everywhere else
  print(1 << 33);
}
''';
