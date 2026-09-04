// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(https://github.com/dart-lang/tools/issues/494): Fix and re-enable this.
@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:test/test.dart';

// The scriptId for the main_test.js in the sample report.
const String mainScriptId = '31';

Future<String> sourceMapProvider(String scriptId) async {
  if (scriptId != mainScriptId) {
    return 'something invalid!';
  }
  return File('test/test_files/main_test.js.map').readAsString();
}

Future<String?> sourceProvider(String scriptId) async {
  if (scriptId != mainScriptId) return null;
  return File('test/test_files/main_test.js').readAsString();
}

Future<Uri> sourceUriProvider(String sourceUrl, String scriptId) async =>
    Uri.parse(sourceUrl);

void main() {
  test('reports correctly', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;

    final report = await parseChromeCoverage(
      preciseCoverage.cast(),
      sourceProvider,
      sourceMapProvider,
      sourceUriProvider,
    );

    final sourceReport = (report['coverage'] as List<Map<String, dynamic>>)
        .firstWhere(
          (Map<String, dynamic> report) =>
              report['source'].toString().contains('main_test.dart'),
        );

    final expectedHits = {
      7: 1,
      11: 1,
      13: 1,
      14: 1,
      17: 0,
      19: 0,
      20: 0,
      22: 1,
      23: 1,
      24: 1,
      25: 1,
      28: 1,
      30: 0,
      32: 1,
      34: 1,
      35: 1,
      36: 1,
    };

    final hitMap = sourceReport['hits'] as List<int>;
    expect(hitMap.length, equals(expectedHits.keys.length * 2));
    for (var i = 0; i < hitMap.length; i += 2) {
      expect(expectedHits[hitMap[i]], equals(hitMap[i + 1]));
    }
  });

  test('HitMap.parseFiles parses Chrome coverage reports', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;

    final report = await parseChromeCoverage(
      preciseCoverage.cast(),
      sourceProvider,
      sourceMapProvider,
      sourceUriProvider,
    );

    final tempDir = Directory.systemTemp.createTempSync('hitmap_chrome_test_');
    final tempFile = File('${tempDir.path}/report.chrome.json');
    tempFile.writeAsStringSync(jsonEncode(report));
    try {
      final hitmap = await HitMap.parseFiles([tempFile]);
      expect(hitmap.keys, anyElement(contains('main_test.dart')));
      final key = hitmap.keys.firstWhere((k) => k.contains('main_test.dart'));
      final fileHitMap = hitmap[key]!;
      expect(fileHitMap.lineHits[7], equals(1));
      expect(fileHitMap.lineHits[11], equals(1));
      expect(fileHitMap.lineHits[17], equals(0));
      expect(fileHitMap.lineHits[36], equals(1));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('HitMap.parseFiles handles raw V8 list with providers', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;
    final tempDir = Directory.systemTemp.createTempSync('hitmap_v8_raw_test_');
    final tempFile = File('${tempDir.path}/raw_v8.json');
    tempFile.writeAsStringSync(jsonEncode(preciseCoverage));
    try {
      final hitmap = await HitMap.parseFiles(
        [tempFile],
        sourceProvider: (scriptId) async => sourceProvider(scriptId),
        sourceMapProvider: (scriptId) async => sourceMapProvider(scriptId),
      );
      expect(hitmap.keys, anyElement(contains('main_test.dart')));
      final key = hitmap.keys.firstWhere((k) => k.contains('main_test.dart'));
      final fileHitMap = hitmap[key]!;
      expect(fileHitMap.lineHits[7], equals(1));
      expect(fileHitMap.lineHits[11], equals(1));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Regression tests for the `scriptId` validation added alongside the
  // pattern-matching dispatch in `HitMap.parseFiles`.
  test('parseChromeCoverage rejects an entry with a missing scriptId', () {
    expect(
      parseChromeCoverage(
        [
          <String, dynamic>{
            'url': 'http://localhost/main_test.js',
            'functions': <Map<String, dynamic>>[],
          },
        ],
        sourceProvider,
        sourceMapProvider,
        sourceUriProvider,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('parseChromeCoverage rejects a non-String scriptId', () {
    expect(
      parseChromeCoverage(
        [
          <String, dynamic>{
            'scriptId': 31,
            'url': 'http://localhost/main_test.js',
            'functions': <Map<String, dynamic>>[],
          },
        ],
        sourceProvider,
        sourceMapProvider,
        sourceUriProvider,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('HitMap.parseFiles skips non-map entries in a coverage list', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;
    final report = await parseChromeCoverage(
      preciseCoverage.cast(),
      sourceProvider,
      sourceMapProvider,
      sourceUriProvider,
    );

    final tempDir = Directory.systemTemp.createTempSync('hitmap_mixed_test_');
    final tempFile = File('${tempDir.path}/report.json');
    tempFile.writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'type': 'CodeCoverage',
        'coverage': <dynamic>['not-a-map', 42, ...report['coverage'] as List],
      }),
    );
    try {
      final hitmap = await HitMap.parseFiles([tempFile]);
      expect(hitmap.keys, anyElement(contains('main_test.dart')));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('HitMap.parseFiles skips non-map entries in a raw V8 list', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;
    final tempDir = Directory.systemTemp.createTempSync('hitmap_v8_mixed_');
    final tempFile = File('${tempDir.path}/raw_v8.json');
    tempFile.writeAsStringSync(
      jsonEncode(<dynamic>['not-a-map', 42, ...preciseCoverage]),
    );
    try {
      final hitmap = await HitMap.parseFiles(
        [tempFile],
        sourceProvider: (scriptId) async => sourceProvider(scriptId),
        sourceMapProvider: (scriptId) async => sourceMapProvider(scriptId),
      );
      expect(hitmap.keys, anyElement(contains('main_test.dart')));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('HitMap.parseFiles returns an empty hitmap for a raw V8 list when no '
      'providers are supplied', () async {
    final preciseCoverage =
        json.decode(
              await File(
                'test/test_files/chrome_precise_report.txt',
              ).readAsString(),
            )
            as List;
    final tempDir = Directory.systemTemp.createTempSync('hitmap_v8_noprov_');
    final tempFile = File('${tempDir.path}/raw_v8.json');
    tempFile.writeAsStringSync(jsonEncode(preciseCoverage));
    try {
      // The default providers must resolve to null (not throw), so a raw V8
      // report without source/source-map access degrades to an empty hitmap.
      expect(await HitMap.parseFiles([tempFile]), isEmpty);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Silently ignoring an unrecognized file would under-report coverage: a
  // truncated or corrupt report would look like a run with no hits.
  group('HitMap.parseFiles rejects unrecognized JSON', () {
    for (final contents in [
      '{"coverage": null}',
      '{"coverage": {}}',
      '{"coverage": "nope"}',
      '{}',
      '"a string"',
      '42',
      'null',
    ]) {
      test(contents, () async {
        final tempDir = Directory.systemTemp.createTempSync('hitmap_bad_');
        final tempFile = File('${tempDir.path}/bad.json')
          ..writeAsStringSync(contents);
        try {
          expect(
            () => HitMap.parseFiles([tempFile]),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                allOf(contains('Unrecognized coverage JSON'), contains('bad')),
              ),
            ),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    }
  });
}
