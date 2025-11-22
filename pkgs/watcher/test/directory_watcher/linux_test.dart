// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('linux')
library;

import 'package:test/test.dart';
import 'package:watcher/src/directory_watcher/linux.dart';
import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'end_to_end_tests.dart';
import 'file_tests.dart';
import 'link_tests.dart';

void main() {
  watcherFactory = LinuxDirectoryWatcher.new;

  fileTests(isNative: true);
  linkTests(isNative: true);
  endToEndTests();

  test('DirectoryWatcher creates a LinuxDirectoryWatcher on Linux', () {
    expect(DirectoryWatcher('.'), const TypeMatcher<LinuxDirectoryWatcher>());
  });
}
