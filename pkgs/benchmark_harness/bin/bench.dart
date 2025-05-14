// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/src/compile_and_run.dart' show compileAndRun;

Future<void> main(List<String> args) async {
  final modeVal = args[0];
  final target = args[1];

  final modes = modeVal.split(',');

  await compileAndRun(
    target,
    modes,
  );
}
