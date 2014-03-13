// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library all_test;

import 'benchmark_harness_test.dart' as benchmark_harness_test;
import 'result_emitter_test.dart' as result_emitter_test;

void main() {
  benchmark_harness_test.main();
  result_emitter_test.main();
}
