// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Retry(3)
import 'dart:async';
import 'dart:convert' show json, LineSplitter, utf8;
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:coverage/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_util.dart';

final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');
final _collectAppPath = p.join('bin', 'collect_coverage.dart');

final _sampleAppFileUri = p.toUri(p.absolute(testAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

void main() {
  test('collect_coverage', () async {
    final resultString = await _getCoverageResult();

    // analyze the output json
    final jsonResult = json.decode(resultString) as Map<String, dynamic>;

    expect(jsonResult.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(jsonResult, containsPair('type', 'CodeCoverage'));

    final coverage = jsonResult['coverage'] as List;
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
  });

  test('createHitmap', () async {
    final resultString = await _getCoverageResult();
    final jsonResult = json.decode(resultString) as Map<String, dynamic>;
    final coverage = jsonResult['coverage'] as List;
    final hitMap = createHitmap(coverage.cast<Map<String, dynamic>>());
    expect(hitMap, contains(_sampleAppFileUri));

    final isolateFile = hitMap[_isolateLibFileUri];
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
    if (Platform.version.startsWith('1.')) {
      // Dart VMs prior to 2.0.0-dev.5.0 contain a bug that emits coverage on the
      // closing brace of async function blocks.
      // See: https://github.com/dart-lang/coverage/issues/196
      expectedHits[23] = 0;
    } else {
      // Dart VMs version 2.0.0-dev.6.0 mark the opening brace of a function as
      // coverable.
      expectedHits[11] = 1;
      expectedHits[18] = 1;
      expectedHits[28] = 1;
      expectedHits[32] = 3;
    }
    expect(isolateFile, expectedHits);
  });

  test('parseCoverage', () async {
    final tempDir = await Directory.systemTemp.createTemp('coverage.test.');

    try {
      final outputFile = File(p.join(tempDir.path, 'coverage.json'));

      final coverageResults = await _getCoverageResult();
      await outputFile.writeAsString(coverageResults, flush: true);

      final parsedResult = await parseCoverage([outputFile], 1);

      expect(parsedResult, contains(_sampleAppFileUri));
      expect(parsedResult, contains(_isolateLibFileUri));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}

String _coverageData;

Future<String> _getCoverageResult() async =>
    _coverageData ??= await _collectCoverage();

Future<String> _collectCoverage() async {
  expect(FileSystemEntity.isFileSync(testAppPath), isTrue);

  final openPort = await getOpenPort();

  // Run the sample app with the right flags.
  final sampleProcess = await runTestApp(openPort);

  // Capture the VM service URI.
  final serviceUriCompleter = Completer<Uri>();
  sampleProcess.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    if (!serviceUriCompleter.isCompleted) {
      final serviceUri = extractObservatoryUri(line);
      if (serviceUri != null) {
        serviceUriCompleter.complete(serviceUri);
      }
    }
  });
  final serviceUri = await serviceUriCompleter.future;

  // Run the collection tool.
  // TODO: need to get all of this functionality in the lib
  final toolResult = await Process.run('dart', [
    _collectAppPath,
    '--uri',
    '$serviceUri',
    '--resume-isolates',
    '--wait-paused'
  ]).timeout(timeout, onTimeout: () {
    throw 'We timed out waiting for the tool to finish.';
  });

  if (toolResult.exitCode != 0) {
    print(toolResult.stdout);
    print(toolResult.stderr);
    fail('Tool failed with exit code ${toolResult.exitCode}.');
  }

  await sampleProcess.exitCode;
  await sampleProcess.stderr.drain<List<int>>();

  return toolResult.stdout as String;
}
