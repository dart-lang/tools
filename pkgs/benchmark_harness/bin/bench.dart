// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:benchmark_harness/src/bench_command/bench_options.dart';
import 'package:benchmark_harness/src/bench_command/compile_and_run.dart';

Future<void> main(List<String> args) async {
  BenchOptions? options;

  try {
    options = BenchOptions.fromArgs(args);
    if (options.help) {
      print('''
\nRuns a dart script in a number of runtimes.

Meant to make it easy to run a benchmark executable across runtimes to validate
performance impacts.
''');
      print(BenchOptions.usage);
      return;
    }

    await compileAndRun(options);
  } on ArgParserException catch (e) {
    print(e.message);
    print(BenchOptions.usage);
    exitCode = 64; // command line usage error
  } on FormatException catch (e) {
    print('Error parsing output: ${e.message}');
    if (options?.verbose ?? true) {
      print(e);
    }
    exitCode = 1;
  } on BenchException catch (e, stack) {
    print(e.message);
    if (options?.verbose ?? true) {
      print(e);
      print(stack);
    }
    exitCode = e.exitCode;
  } catch (e, stack) {
    print('An unexpected error occurred: $e');
    if (options?.verbose ?? true) {
      print(stack);
    }
    exitCode = 1;
  }
}
