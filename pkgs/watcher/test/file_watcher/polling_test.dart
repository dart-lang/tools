// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:watcher/watcher.dart';

import '../utils.dart';
import 'file_tests.dart';
import 'link_tests.dart';
import 'startup_race_tests.dart';

void main() {
  watcherFactory = (file) =>
      PollingFileWatcher(file, pollingDelay: const Duration(milliseconds: 100));

  fileTests(isNative: false);
  linkTests(isNative: false);
  startupRaceTests(isNative: false);
}
