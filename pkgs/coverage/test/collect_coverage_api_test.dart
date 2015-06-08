// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.collect_coverage_api_test;

import 'dart:async';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:coverage/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _sampleAppPath = p.join('test', 'test_files', 'test_app.dart');
final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');

final _sampleAppFileUri = p.toUri(p.absolute(_sampleAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

const _timeout = const Duration(seconds: 5);

void main() {
  test('collect_coverage_api', () async {
    var json = await _getCoverageResult();

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
      expect(sampleCoverageData['hits'], isNotEmpty);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]) {
      expect(sampleCoverageData['hits'], isNotEmpty);
    }
  });
}

Map _coverageData;

Future<Map> _getCoverageResult() async {
  if (_coverageData == null) {
    _coverageData = await _collectCoverage();
  }
  return _coverageData;
}

Future<Map> _collectCoverage() async {
  var openPort = await getOpenPort();

  // run the sample app, with the right flags
  var sampleProcFuture = Process
      .run('dart', [
    '--enable-vm-service=$openPort',
    '--pause_isolates_on_exit',
    _sampleAppPath
  ])
      .timeout(_timeout, onTimeout: () {
    throw 'We timed out waiting for the sample app to finish.';
  });

  var result = collect('127.0.0.1', openPort, true, false, timeout: _timeout);
  await sampleProcFuture;

  return result;
}
