// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:test/test.dart';

Future<String> sourceMapProvider(String scriptId) async {
  // The scriptId for the main_test.ddc.js in the sample report is 37.
  if (scriptId != '37') return null;
  return File('test/test_files/main_test.ddc.js.map').readAsString();
}

Future<String> sourceProvider(String scriptId) async {
  // The scriptId for the main_test.ddc.js in the sample report is 37.
  if (scriptId != '37') return null;
  return File('test/test_files/main_test.ddc.js').readAsString();
}

Future<Uri> sourceUriProvider(String sourceUrl, String scriptId) async =>
    Uri.parse(sourceUrl);

void main() {
  test('reports correctly', () async {
    final preciseCoverage = json.decode(
        await File('test/test_files/chrome_precise_report.txt').readAsString());

    final report = await parseChromeCoverage(
      // ignore: avoid_as
      (preciseCoverage as List).cast(),
      sourceProvider,
      sourceMapProvider,
      sourceUriProvider,
    );

    final coverage = report['coverage'];
    expect(coverage.length, equals(1));

    final sourceReport = coverage.first;
    expect(sourceReport['source'], equals('main_test.dart'));

    final Map<int, int> expectedHits = {
      5: 1,
      6: 1,
      7: 1,
      8: 0,
      10: 1,
      11: 1,
      13: 1,
      14: 1,
      15: 1,
    };

    final List<int> hitMap = sourceReport['hits'];
    expect(hitMap.length, equals(expectedHits.keys.length * 2));
    for (var i = 0; i < hitMap.length; i += 2) {
      expect(expectedHits[hitMap[i]], equals(hitMap[i + 1]));
    }
  });
}
