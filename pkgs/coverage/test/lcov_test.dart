// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.test.collect_coverage_test;

import 'dart:async';
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
  test('validate hitMap', () async {
    var hitmap = await _getHitMap();

    expect(hitmap, contains(_sampleAppFileUri));
    expect(hitmap, contains(_isolateLibFileUri));
    expect(hitmap, contains('package:coverage/src/util.dart'));

    var sampleAppHitMap = hitmap[_sampleAppFileUri];

    expect(sampleAppHitMap, containsPair(40, greaterThanOrEqualTo(1)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitMap, containsPair(44, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitMap, isNot(contains(28)),
        reason: 'be careful if you modify the test file');
  });

  test('format', () async {
    var hitmap = await _getHitMap();

    var resolver = new Resolver(packageRoot: 'packages');
    var formatter = new LcovFormatter(resolver);

    String res = await formatter.format(hitmap);

    expect(res, contains(p.absolute(_sampleAppPath)));
    expect(res, contains(p.absolute(_isolateLibPath)));
    expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
  });

  test('PrettyPrintFormatter', () async {
    var hitmap = await _getHitMap();

    var resolver = new Resolver(packageRoot: 'packages');
    var formatter = new PrettyPrintFormatter(resolver, new Loader());

    String res = await formatter.format(hitmap);

    expect(res, contains(p.absolute(_sampleAppPath)));
    expect(res, contains(p.absolute(_isolateLibPath)));
    expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

    // be very careful if you change the test file
    expect(res, contains("      0|  return a - b;"));
    expect(res, contains('       |  doRetry() {'));

    var hitLineRegexp = new RegExp(r'\s+(\d+)\|  return a \+ b;');
    var match = hitLineRegexp.allMatches(res).single;

    var hitCount = int.parse(match[1]);
    expect(hitCount, greaterThanOrEqualTo(1));
  });
}

Map _hitMap;

Future<Map> _getHitMap() async {
  if (_hitMap == null) {
    var tempDir = await Directory.systemTemp.createTemp('coverage.test.');
    try {
      var files = await _collectCoverage(tempDir);
      _hitMap = await parseCoverage(files, 1);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }
  return _hitMap;
}

Future<List<File>> _collectCoverage(Directory tempDir) async {
  expect(await FileSystemEntity.isFile(_sampleAppPath), isTrue);

  var args = [
    "--enable-vm-service=0",
    "--coverage_dir=${tempDir.path}",
    _sampleAppPath
  ];
  var result = await Process.run("dart", args);
  if (result.exitCode != 0) {
    throw new ProcessException('dart', args,
        'There was a critical error. Exit code: ${result.exitCode}',
        result.exitCode);
  }

  return await tempDir.list(recursive: false, followLinks: false).toList();
}
