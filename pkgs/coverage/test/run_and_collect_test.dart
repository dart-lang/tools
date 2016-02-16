// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.run_and_collect_test;

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

    expect(json.keys, unorderedEquals(['type', 'coverage']));

    expect(json, containsPair('type', 'CodeCoverage'));

    var coverage = json['coverage'] as List;
    expect(coverage, isNotEmpty);

    var sources = coverage.fold(<String, dynamic>{}, (Map map, Map value) {
      var sourceUri = value['source'];

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

    var isolateFile = hitMap[_isolateLibFileUri];

    expect(isolateFile, {12: 1, 14: 1, 16: 3, 18: 1});
  });
}
