// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.collect_coverage_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _sampleAppPath = p.join('test', 'test_files', 'test_app.dart');
final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');
final _collectAppPath = p.join('bin', 'collect_coverage.dart');

final _sampleAppFileUri = p.toUri(p.absolute(_sampleAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

const _timeout = const Duration(seconds: 5);

void main() {
  test('collect_coverage', () async {
    var resultString = await _getCoverageResult();

    // analyze the output json
    var json = JSON.decode(resultString) as Map;

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

  test('createHitmap', () async {
    var resultString = await _getCoverageResult();

    var json = JSON.decode(resultString) as Map;

    var coverage = json['coverage'] as List;

    var hitMap = createHitmap(coverage);

    expect(hitMap, contains(_sampleAppFileUri));

    var isolateFile = hitMap[_isolateLibFileUri];

    expect(isolateFile, {7: 1, 9: 3, 11: 1, 6: 1});
  });

  test('parseCoverage', () async {
    var tempDir = await Directory.systemTemp.createTemp('coverage.test.');

    var outputFile = new File(p.join(tempDir.path, 'coverage.json'));

    var coverageResults = await _getCoverageResult();
    await outputFile.writeAsString(coverageResults, flush: true);

    var parsedResult = await parseCoverage([outputFile], 1);

    expect(parsedResult, contains(_sampleAppFileUri));
    expect(parsedResult, contains(_isolateLibFileUri));
  });
}

String _coverageData;

Future<String> _getCoverageResult() async {
  if (_coverageData == null) {
    _coverageData = await _collectCoverage();
  }
  return _coverageData;
}

Future<String> _collectCoverage() async {
  expect(await FileSystemEntity.isFile(_sampleAppPath), isTrue);

  // need to find an open port
  var socket = await ServerSocket.bind(InternetAddress.ANY_IP_V4, 0);
  int openPort = socket.port;
  await socket.close();

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

  // run the tool with the right flags
  // TODO: need to get all of this functionality in the lib
  var toolResult = await Process
      .run('dart', [
    _collectAppPath,
    '--port',
    openPort.toString(),
    '--resume-isolates',
    '--resume-isolates'
  ])
      .timeout(_timeout, onTimeout: () {
    throw 'We timed out waiting for the tool to finish.';
  });

  await sampleProcFuture;

  expect(toolResult.exitCode, 0);

  return toolResult.stdout;
}
