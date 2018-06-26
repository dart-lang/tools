// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_util.dart';

final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');

final _sampleAppFileUri = p.toUri(p.absolute(testAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

void main() {
  test('runAndCollect', () async {
    // use runAndCollect and verify that the results match w/ running manually
    var json = await runAndCollect(testAppPath);
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    List<Map> coverage = json['coverage'];
    expect(coverage, isNotEmpty);

    var sources = coverage.fold({}, (Map map, value) {
      String sourceUri = value['source'];
      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
      return map;
    });

    for (var sampleCoverageData in sources[_sampleAppFileUri]) {
      expect(sampleCoverageData['hits'], isNotNull);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]) {
      expect(sampleCoverageData['hits'], isNotEmpty);
    }

    var hitMap = createHitmap(coverage);
    expect(hitMap, contains(_sampleAppFileUri));

    Map<int, int> isolateFile = hitMap[_isolateLibFileUri];
    Map<int, int> expectedHits = {
      10: 1,
      11: 1,
      13: 0,
      17: 1,
      18: 1,
      20: 0,
      27: 1,
      29: 1,
      30: 2,
      31: 1,
      32: 3,
      33: 1,
    };
    // Dart VMs prior to 2.0.0-dev.5.0 contain a bug that emits coverage on the
    // closing brace of async function blocks.
    // See: https://github.com/dart-lang/coverage/issues/196
    if (Platform.version.startsWith('1.')) {
      expectedHits[21] = 0;
    } else {
      // Dart VMs version 2.0.0-dev.6.0 mark the opening brace of a function as
      // coverable.
      expectedHits[9] = 1;
      expectedHits[16] = 1;
      expectedHits[26] = 1;
      expectedHits[30] = 3;
    }
    expect(isolateFile, expectedHits);
  });
}
