// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:benchmark_harness/src/bench.dart';
import 'package:benchmark_harness/src/compile_and_run.dart';

Future<void> main(List<String> args) async {
  BenchOptions? options;

  try {
    options = BenchOptions.fromArgs(args);
    if (options.help) {
      print(BenchOptions.usage);
      return;
    }

    await compileAndRun(options);
  } on FormatException catch (e) {
    print(e.message);
    print(BenchOptions.usage);
    exitCode = 64;
    return;
  } on BenchException catch (e, stack) {
    print(e.message);
    if (options?.verbose ?? true) {
      print(e);
      print(stack);
    }
    exitCode = e.exitCode;
  }
}
