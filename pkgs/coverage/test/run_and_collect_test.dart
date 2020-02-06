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
    final json = await runAndCollect(testAppPath);
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final coverage = json['coverage'] as List<Map<String, dynamic>>;
    expect(coverage, isNotEmpty);

    final sources = coverage.fold<Map<String, dynamic>>(<String, dynamic>{},
        (Map<String, dynamic> map, dynamic value) {
      final sourceUri = value['source'] as String;
      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
      return map;
    });

    for (var sampleCoverageData in sources[_sampleAppFileUri]) {
      expect(sampleCoverageData['hits'], isNotNull);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]) {
      expect(sampleCoverageData['hits'], isNotEmpty);
    }

    final hitMap = createHitmap(coverage);
    expect(hitMap, contains(_sampleAppFileUri));

    final actualHits = hitMap[_isolateLibFileUri];
    final expectedHits = {
      12: 1,
      13: 1,
      15: 0,
      19: 1,
      20: 1,
      22: 0,
      29: 1,
      31: 1,
      32: 2,
      33: 1,
      34: 3,
      35: 1,
    };
    // Dart VMs prior to 2.0.0-dev.5.0 contain a bug that emits coverage on the
    // closing brace of async function blocks.
    // See: https://github.com/dart-lang/coverage/issues/196
    if (Platform.version.startsWith('1.')) {
      expectedHits[23] = 0;
    } else {
      // Dart VMs version 2.0.0-dev.6.0 mark the opening brace of a function as
      // coverable.
      expectedHits[11] = 1;
      expectedHits[18] = 1;
      expectedHits[28] = 1;
      expectedHits[32] = 3;
    }
    expect(actualHits, expectedHits);
  });
}
