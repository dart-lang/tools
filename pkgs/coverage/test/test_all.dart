// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'chrome_test.dart' as chrome;
import 'collect_coverage_api_test.dart' as collect_coverage_api;
import 'collect_coverage_test.dart' as collect_coverage;
import 'format_coverage_test.dart' as format_coverage;
import 'lcov_test.dart' as lcov;
import 'resolver_test.dart' as resolver;
import 'run_and_collect_test.dart' as run_and_collect;
import 'util_test.dart' as util;

void main() {
  group('collect_coverage_api', collect_coverage_api.main);
  group('collect_coverage', collect_coverage.main);
  group('format_coverage', format_coverage.main);
  group('lcov', lcov.main);
  group('resolver', resolver.main);
  group('run_and_collect', run_and_collect.main);
  group('util', util.main);
  group('chrome', chrome.main);
}
