// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

    final hitMap = await HitMap.parseJson(coverage, checkIgnoredLines: true);
    expect(hitMap, isNot(contains(_sampleAppFileUri)));

    final actualHitMap = hitMap[_isolateLibFileUri];
    final actualLineHits = actualHitMap?.lineHits;
    final expectedLineHits = {
      11: 1,
      12: 1,
      13: 1,
      15: 0,
      19: 1,
      23: 1,
      24: 2,
      28: 1,
      29: 1,
      30: 1,
      32: 0,
      38: 1,
      39: 1,
      41: 1,
      42: 3,
      43: 1,
      44: 3,
      45: 1,
      48: 1,
      49: 1,
      59: 1,
      60: 1
    };

    expect(actualLineHits, expectedLineHits);
    expect(actualHitMap?.funcHits, isNull);
    expect(actualHitMap?.funcNames, isNull);
    expect(actualHitMap?.branchHits, isNull);
  });
}
