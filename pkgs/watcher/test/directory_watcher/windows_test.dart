// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')
@Timeout.factor(2)
library;

import 'package:test/test.dart';
import 'package:watcher/src/directory_watcher/recursive/recursive_directory_watcher.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'end_to_end_tests.dart';
import 'file_tests.dart';
import 'link_tests.dart';

void main() {
  watcherFactory = (directory) =>
      RecursiveDirectoryWatcher(directory, runInIsolate: true);

  fileTests(isNative: true);
  linkTests(isNative: true);
  endToEndTests();

  test('DirectoryWatcher creates a RecursiveDirectoryWatcher on Windows', () {
    expect(
      DirectoryWatcher('.'),
      const TypeMatcher<RecursiveDirectoryWatcher>(),
    );
  });
}
