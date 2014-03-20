#!/usr/bin/env dart
library hop_runner;

import 'dart:io';
import 'dart:async';

import 'package:hop/hop.dart';
import 'package:hop/hop_tasks.dart';

import 'package:path/path.dart' as path;

import '../test/benchmark_harness_test.dart' as benchmark_harness_test;
import '../test/result_emitter_test.dart' as result_emitter_test;

void main(List<String> args) {
  addTask('analyze_libs', createAnalyzerTask(_getDartFiles('lib')));
  addTask('analyze_examples', createAnalyzerTask(_getDartFiles('example')));
  addTask('analyze_tests', createAnalyzerTask(_getDartFiles('test')));

  addChainedTask('analyze_all',
      ['analyze_libs', 'analyze_examples', 'analyze_tests']);

  addTask('test', createUnitTestTask((){
    benchmark_harness_test.main();
    result_emitter_test.main();
  }));

  runHop(args);
}

Future<List<String>> _getDartFiles(String directory) =>
  new Directory(directory)
    .list()
    .where((FileSystemEntity fse) => fse is File)
    .map((File file) => file.path)
    .where((String filePath) => path.extension(filePath) == '.dart')
    .toList();
