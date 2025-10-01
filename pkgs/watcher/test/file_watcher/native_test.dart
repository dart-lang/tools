// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('linux || mac-os')
library;

import 'package:test/test.dart';
import 'package:watcher/src/file_watcher/native.dart';

import '../utils.dart';
import 'file_tests.dart';
import 'link_tests.dart';
import 'startup_race_tests.dart';

void main() {
  watcherFactory = NativeFileWatcher.new;

  fileTests(isNative: true);
  linkTests(isNative: true);
  startupRaceTests(isNative: true);
}
