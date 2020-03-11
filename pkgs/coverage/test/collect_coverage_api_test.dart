// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:coverage/coverage.dart';
import 'package:coverage/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_util.dart';

final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');

final _sampleAppFileUri = p.toUri(p.absolute(testAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

void main() {
  test('collect throws when serviceUri is null', () {
    expect(() => collect(null, true, false, false, <String>{}),
        throwsArgumentError);
  });

  test('collect_coverage_api', () async {
    final json = await _collectCoverage();
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final coverage = json['coverage'] as List;
    expect(coverage, isNotEmpty);

    final sources = coverage.cast<Map>().fold(<String, List<Map>>{},
        (Map<String, List<Map>> map, value) {
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

  test('collect_coverage_api with scoped output', () async {
    final json =
        await _collectCoverage(scopedOutput: <String>{}..add('coverage'));
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final coverage = json['coverage'] as List;
    expect(coverage, isNotEmpty);

    final sources = coverage.fold(<String, dynamic>{},
        (Map<String, dynamic> map, dynamic value) {
      final sourceUri = value['source'] as String;
      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
      return map;
    });

    for (var key in sources.keys) {
      final uri = Uri.parse(key);
      expect(uri.path.startsWith('coverage'), isTrue);
    }
  });

  test('collect_coverage_api with isolateIds', () async {
    final json = await _collectCoverage(isolateIds: true);
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final coverage = json['coverage'] as List<Map<String, dynamic>>;
    expect(coverage, isNotEmpty);

    final testAppCoverage = _getScriptCoverage(coverage, 'test_app.dart');
    var hits = testAppCoverage['hits'] as List<int>;
    _expectHitCount(hits, 44, 0);
    _expectHitCount(hits, 48, 0);

    final isolateCoverage =
        _getScriptCoverage(coverage, 'test_app_isolate.dart');
    hits = isolateCoverage['hits'] as List<int>;
    _expectHitCount(hits, 11, 1);
    _expectHitCount(hits, 18, 1);
  });
}

Future<Map<String, dynamic>> _collectCoverage(
    {Set<String> scopedOutput, bool isolateIds = false}) async {
  scopedOutput ??= <String>{};
  final openPort = await getOpenPort();

  // run the sample app, with the right flags
  final sampleProcess = await runTestApp(openPort);

  // Capture the VM service URI.
  final serviceUriCompleter = Completer<Uri>();
  final isolateIdCompleter = Completer<String>();
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
    if (line.contains('isolateId = ')) {
      isolateIdCompleter.complete(line.split(' = ')[1]);
    }
  });

  final serviceUri = await serviceUriCompleter.future;
  final isolateId = await isolateIdCompleter.future;
  final isolateIdSet = isolateIds ? {isolateId} : null;

  return collect(serviceUri, true, true, false, scopedOutput,
      timeout: timeout, isolateIds: isolateIdSet);
}

// Returns the first coverage hitmap for the script with with the specified
// script filename, ignoring leading path.
Map<String, dynamic> _getScriptCoverage(
    List<Map<String, dynamic>> coverage, String filename) {
  for (var isolateCoverage in coverage) {
    final script = Uri.parse(isolateCoverage['script']['uri'] as String);
    if (script.pathSegments.last == filename) {
      return isolateCoverage;
    }
  }
  return null;
}

/// Tests that the specified hitmap has the specified hit count for the
/// specified line.
void _expectHitCount(List<int> hits, int line, int hitCount) {
  final hitIndex = hits.indexOf(line);
  if (hitIndex < 0) {
    fail('No hit count for line $line');
  }
  final actual = hits[hitIndex + 1];
  expect(actual, equals(hitCount),
      reason: 'Expected line $line to have $hitCount hits, but found $actual.');
}
