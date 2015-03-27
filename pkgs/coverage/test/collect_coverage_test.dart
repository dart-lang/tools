// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.collect_coverage_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _sampleAppPath = p.join('test', 'test_files', 'test_app.dart');
final _collectAppPath = p.join('bin', 'collect_coverage.dart');

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

    var sources = coverage.fold(new Map(), (Map map, Map value) {
      var sourceUri = Uri.parse(value['source']);

      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);

      return map;
    });

    var fullSamplePath = p.toUri(p.absolute(_sampleAppPath));

    var sampleCoverageData = sources[fullSamplePath].single;

    expect(sampleCoverageData['hits'], isNotEmpty);
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
