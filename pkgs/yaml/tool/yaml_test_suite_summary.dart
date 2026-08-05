// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:test/test.dart';
import '../test/yaml_test_suite.dart';

void main(List<String> args) {
  final cases = loadYamlTestSuite();

  if (args.isNotEmpty) {
    final targetId = args.first;
    final testCase = cases.cast<YamlTestCase?>().firstWhere(
          (c) => c?.id == targetId,
          orElse: () => null,
        );

    if (testCase == null) {
      print('Test case $targetId not found.');
      exit(1);
    }

    print('Test Case: ${testCase.id} - ${testCase.name}');
    print('Tags: ${testCase.tags.join(', ')}');
    print('Fail expected: ${testCase.fail}');
    print('--- YAML ---');
    print(testCase.yaml);
    print('------------');

    try {
      testCase.runTest();
      print('Status: PASSED');
    } on TestFailure catch (e) {
      print('Status: FAILED (TestFailure)');
      print(e.message);
    } catch (e) {
      print('Status: FAILED (Unexpected Exception)');
      print(e.toString());
    }
    return;
  }

  final tagFailures = <String, List<String>>{};
  final expectedParsingFailIds = <String>[];
  final mismatchingJsonIds = <String>[];
  final unexpectedErrorIds = <String>[];

  for (final c in cases) {
    try {
      c.runTest();
    } on TestFailure catch (e) {
      for (final tag in c.tags) {
        tagFailures.putIfAbsent(tag, () => []).add(c.id);
      }

      if (e.message?.contains('Expected parsing to fail') == true) {
        expectedParsingFailIds.add(c.id);
      } else if (e.message?.contains('JSON mismatch') == true) {
        mismatchingJsonIds.add(c.id);
      } else {
        unexpectedErrorIds.add(c.id);
      }
    } catch (e) {
      // Any other exception from parser
      for (final tag in c.tags) {
        tagFailures.putIfAbsent(tag, () => []).add(c.id);
      }
      unexpectedErrorIds.add(c.id);
    }
  }

  print('Failures by Tag:');
  final sortedTags = tagFailures.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));

  // Calculate max length of tag for alignment
  final maxTagLen = tagFailures.keys
      .fold<int>(0, (max, tag) => tag.length > max ? tag.length : max);

  for (final entry in sortedTags) {
    final countStr = entry.value.length.toString().padLeft(4);
    final tagPadded = entry.key.padRight(maxTagLen);
    final samples = entry.value.take(5).join(' ');
    print('  $tagPadded: $countStr          $samples');
  }

  print('');
  print('Total Failures:');

  final categories = [
    ('Expected parsing to fail', expectedParsingFailIds),
    ('Mismatching JSON', mismatchingJsonIds),
    ('Unexpected errors', unexpectedErrorIds),
  ];

  final maxCatLen = categories.fold<int>(
      0, (max, cat) => cat.$1.length > max ? cat.$1.length : max);

  for (final cat in categories) {
    final namePadded = cat.$1.padRight(maxCatLen);
    final countStr = cat.$2.length.toString().padLeft(4);
    final samples = cat.$2.take(5).join(' ');
    print('  $namePadded: $countStr          $samples');
  }
}
