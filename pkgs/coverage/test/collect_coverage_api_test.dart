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

    for (var sampleCoverageData in sources[_sampleAppFileUri]!) {
      expect(sampleCoverageData['hits'], isNotEmpty);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]!) {
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
    expect(coverage, isEmpty);
  });

  test('collect_coverage_api with function coverage', () async {
    final json = await _collectCoverage(functionCoverage: true);
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

    for (var sampleCoverageData in sources[_sampleAppFileUri]!) {
      expect(sampleCoverageData['funcNames'], isNotEmpty);
      expect(sampleCoverageData['funcHits'], isNotEmpty);
    }

    for (var sampleCoverageData in sources[_isolateLibFileUri]!) {
      expect(sampleCoverageData['funcNames'], isNotEmpty);
      expect(sampleCoverageData['funcHits'], isNotEmpty);
    }
  });

  test('collect_coverage_api with branch coverage', () async {
    final json = await _collectCoverage(branchCoverage: true);
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

    // Dart VM versions before 2.17 don't support branch coverage.
    expect(sources[_sampleAppFileUri],
        everyElement(containsPair('branchHits', isNotEmpty)));
    expect(sources[_isolateLibFileUri],
        everyElement(containsPair('branchHits', isNotEmpty)));
  }, skip: !platformVersionCheck(2, 17));
}

Future<Map<String, dynamic>> _collectCoverage(
    {Set<String> scopedOutput = const {},
    bool isolateIds = false,
    bool functionCoverage = false,
    bool branchCoverage = false}) async {
  final openPort = await getOpenPort();

  // run the sample app, with the right flags
  final sampleProcess = await runTestApp(openPort);

  // Capture the VM service URI.
  final serviceUriCompleter = Completer<Uri>();
  sampleProcess.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    if (!serviceUriCompleter.isCompleted) {
      final serviceUri = extractVMServiceUri(line);
      if (serviceUri != null) {
        serviceUriCompleter.complete(serviceUri);
      }
    }
  });

  final serviceUri = await serviceUriCompleter.future;
  final isolateIdSet = isolateIds ? <String>{} : null;

  return collect(serviceUri, true, true, false, scopedOutput,
      timeout: timeout,
      isolateIds: isolateIdSet,
      functionCoverage: functionCoverage,
      branchCoverage: branchCoverage);
}
