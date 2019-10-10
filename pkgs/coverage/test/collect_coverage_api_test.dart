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
    expect(() => collect(null, true, false, false, Set<String>()),
        throwsArgumentError);
  });

  test('collect_coverage_api', () async {
    final Map<String, dynamic> json = await _collectCoverage();
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final List coverage = json['coverage'];
    expect(coverage, isNotEmpty);

    final sources = coverage.fold(<String, dynamic>{},
        (Map<String, dynamic> map, dynamic value) {
      final String sourceUri = value['source'];
      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
      return map;
    });

    for (Map sampleCoverageData in sources[_sampleAppFileUri]) {
      expect(sampleCoverageData['hits'], isNotNull);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]) {
      expect(sampleCoverageData['hits'], isNotEmpty);
    }
  });

  test('collect_coverage_api with scoped output', () async {
    final Map<String, dynamic> json =
        await _collectCoverage(scopedOutput: Set<String>()..add('coverage'));
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final List coverage = json['coverage'];
    expect(coverage, isNotEmpty);

    final sources = coverage.fold(<String, dynamic>{},
        (Map<String, dynamic> map, dynamic value) {
      final String sourceUri = value['source'];
      map.putIfAbsent(sourceUri, () => <Map>[]).add(value);
      return map;
    });

    for (var key in sources.keys) {
      final uri = Uri.parse(key);
      expect(uri.path.startsWith('coverage'), isTrue);
    }
  });

  test('collect_coverage_api with isolateIds', () async {
    final Map<String, dynamic> json = await _collectCoverage(isolateIds: true);
    expect(json.keys, unorderedEquals(<String>['type', 'coverage']));
    expect(json, containsPair('type', 'CodeCoverage'));

    final List coverage = json['coverage'];
    expect(coverage, isNotEmpty);

    final Map<String, dynamic> testAppCoverage =
        _getScriptCoverage(coverage, 'test_app.dart');
    List<int> hits = testAppCoverage['hits'];
    _expectHitCount(hits, 44, 0);
    _expectHitCount(hits, 48, 0);

    final Map<String, dynamic> isolateCoverage =
        _getScriptCoverage(coverage, 'test_app_isolate.dart');
    hits = isolateCoverage['hits'];
    _expectHitCount(hits, 11, 1);
    _expectHitCount(hits, 18, 1);
  });
}

Future<Map<String, dynamic>> _collectCoverage(
    {Set<String> scopedOutput, bool isolateIds = false}) async {
  scopedOutput ??= Set<String>();
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
      final Uri serviceUri = extractObservatoryUri(line);
      if (serviceUri != null) {
        serviceUriCompleter.complete(serviceUri);
      }
    }
    if (line.contains('isolateId = ')) {
      isolateIdCompleter.complete(line.split(' = ')[1]);
    }
  });

  final Uri serviceUri = await serviceUriCompleter.future;
  final String isolateId = await isolateIdCompleter.future;
  final Set<String> isolateIdSet = isolateIds ? Set.of([isolateId]) : null;

  return collect(serviceUri, true, true, false, scopedOutput,
      timeout: timeout, isolateIds: isolateIdSet);
}

// Returns the first coverage hitmap for the script with with the specified
// script filename, ignoring leading path.
Map<String, dynamic> _getScriptCoverage(
    List<Map<String, dynamic>> coverage, String filename) {
  for (Map<String, dynamic> isolateCoverage in coverage) {
    final Uri script = Uri.parse(isolateCoverage['script']['uri']);
    if (script.pathSegments.last == filename) {
      return isolateCoverage;
    }
  }
  return null;
}

/// Tests that the specified hitmap has the specified hit count for the
/// specified line.
void _expectHitCount(List<int> hits, int line, int hitCount) {
  final int hitIndex = hits.indexOf(line);
  if (hitIndex < 0) {
    fail('No hit count for line $line');
  }
  final int actual = hits[hitIndex + 1];
  expect(actual, equals(hitCount),
      reason: 'Expected line $line to have $hitCount hits, but found $actual.');
}
