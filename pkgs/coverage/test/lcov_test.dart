// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:coverage/src/util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_util.dart';

final _sampleAppPath = p.join('test', 'test_files', 'test_app.dart');
final _isolateLibPath = p.join('test', 'test_files', 'test_app_isolate.dart');

final _sampleAppFileUri = p.toUri(p.absolute(_sampleAppPath)).toString();
final _isolateLibFileUri = p.toUri(p.absolute(_isolateLibPath)).toString();

void main() {
  test('validate hitMap', () async {
    final hitmap = await _getHitMap();

    expect(hitmap, contains(_sampleAppFileUri));
    expect(hitmap, contains(_isolateLibFileUri));
    expect(hitmap, contains('package:coverage/src/util.dart'));

    final sampleAppHitMap = hitmap[_sampleAppFileUri];
    final sampleAppHitLines = sampleAppHitMap?.lineHits;
    final sampleAppHitFuncs = sampleAppHitMap?.funcHits;
    final sampleAppFuncNames = sampleAppHitMap?.funcNames;
    final sampleAppBranchHits = sampleAppHitMap?.branchHits;

    expect(sampleAppHitLines, containsPair(46, greaterThanOrEqualTo(1)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitLines, containsPair(50, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitLines, isNot(contains(32)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitFuncs, containsPair(45, 1),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitFuncs, containsPair(49, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppFuncNames, containsPair(45, 'usedMethod'),
        reason: 'be careful if you modify the test file');
    expect(sampleAppBranchHits, containsPair(41, 1),
        reason: 'be careful if you modify the test file');
  }, skip: !platformVersionCheck(2, 17));

  test('validate hitMap, old VM without branch coverage', () async {
    final hitmap = await _getHitMap();

    expect(hitmap, contains(_sampleAppFileUri));
    expect(hitmap, contains(_isolateLibFileUri));
    expect(hitmap, contains('package:coverage/src/util.dart'));

    final sampleAppHitMap = hitmap[_sampleAppFileUri];
    final sampleAppHitLines = sampleAppHitMap?.lineHits;
    final sampleAppHitFuncs = sampleAppHitMap?.funcHits;
    final sampleAppFuncNames = sampleAppHitMap?.funcNames;

    expect(sampleAppHitLines, containsPair(46, greaterThanOrEqualTo(1)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitLines, containsPair(50, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitLines, isNot(contains(32)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitFuncs, containsPair(45, 1),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitFuncs, containsPair(49, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppFuncNames, containsPair(45, 'usedMethod'),
        reason: 'be careful if you modify the test file');
  }, skip: platformVersionCheck(2, 17));

  group('LcovFormatter', () {
    test('format()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      // ignore: deprecated_member_use_from_same_package
      final formatter = LcovFormatter(resolver);

      final res = await formatter
          .format(hitmap.map((key, value) => MapEntry(key, value.lineHits)));

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('formatLcov()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = hitmap.formatLcov(resolver);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('formatLcov() includes files in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = hitmap.formatLcov(resolver, reportOn: ['lib/', 'test/']);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('formatLcov() excludes files not in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = hitmap.formatLcov(resolver, reportOn: ['lib/']);

      expect(res, isNot(contains(p.absolute(_sampleAppPath))));
      expect(res, isNot(contains(p.absolute(_isolateLibPath))));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('formatLcov() uses paths relative to basePath', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = hitmap.formatLcov(resolver, basePath: p.absolute('lib'));

      expect(
          res, isNot(contains(p.absolute(p.join('lib', 'src', 'util.dart')))));
      expect(res, contains(p.join('src', 'util.dart')));
    });
  });

  group('PrettyPrintFormatter', () {
    test('format()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      // ignore: deprecated_member_use_from_same_package
      final formatter = PrettyPrintFormatter(resolver, Loader());

      final res = await formatter
          .format(hitmap.map((key, value) => MapEntry(key, value.lineHits)));

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

      // be very careful if you change the test file
      expect(res, contains('      0|  return a - b;'));

      expect(res, contains('|  return _withTimeout(() async {'),
          reason: 'be careful if you change lib/src/util.dart');

      final hitLineRegexp = RegExp(r'\s+(\d+)\|  return a \+ b;');
      final match = hitLineRegexp.allMatches(res).single;

      final hitCount = int.parse(match[1]!);
      expect(hitCount, greaterThanOrEqualTo(1));
    });

    test('prettyPrint()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = await hitmap.prettyPrint(resolver, Loader());

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

      // be very careful if you change the test file
      expect(res, contains('      0|  return a - b;'));

      expect(res, contains('|  return _withTimeout(() async {'),
          reason: 'be careful if you change lib/src/util.dart');

      final hitLineRegexp = RegExp(r'\s+(\d+)\|  return a \+ b;');
      final match = hitLineRegexp.allMatches(res).single;

      final hitCount = int.parse(match[1]!);
      expect(hitCount, greaterThanOrEqualTo(1));
    });

    test('prettyPrint() includes files in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res = await hitmap
          .prettyPrint(resolver, Loader(), reportOn: ['lib/', 'test/']);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('prettyPrint() excludes files not in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res =
          await hitmap.prettyPrint(resolver, Loader(), reportOn: ['lib/']);

      expect(res, isNot(contains(p.absolute(_sampleAppPath))));
      expect(res, isNot(contains(p.absolute(_isolateLibPath))));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('prettyPrint() functions', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res =
          await hitmap.prettyPrint(resolver, Loader(), reportFuncs: true);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

      // be very careful if you change the test file
      expect(res, contains('      1|Future<void> main() async {'));
      expect(res, contains('      1|int usedMethod(int a, int b) {'));
      expect(res, contains('      0|int unusedMethod(int a, int b) {'));
      expect(res, contains('       |  return a + b;'));
    });

    test('prettyPrint() branches', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.dart_tool/package_config.json');
      final res =
          await hitmap.prettyPrint(resolver, Loader(), reportBranches: true);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

      // be very careful if you change the test file
      expect(res, contains('      1|  if (x == answer) {'));
      expect(res, contains('      0|  while (i < lines.length) {'));
      expect(res, contains('       |  bar.baz();'));
    }, skip: !platformVersionCheck(2, 17));
  });
}

Future<Map<String, HitMap>> _getHitMap() async {
  expect(FileSystemEntity.isFileSync(_sampleAppPath), isTrue);

  // select service port.
  final port = await getOpenPort();

  // start sample app.
  final sampleAppArgs = [
    '--pause-isolates-on-exit',
    '--enable-vm-service=$port',
    // Dart VM versions before 2.17 don't support branch coverage.
    if (platformVersionCheck(2, 17)) '--branch-coverage',
    _sampleAppPath
  ];
  final sampleProcess =
      await Process.start(Platform.resolvedExecutable, sampleAppArgs);

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

  // collect hit map.
  final coverageJson = (await collect(serviceUri, true, true, false, <String>{},
      functionCoverage: true,
      branchCoverage: true))['coverage'] as List<Map<String, dynamic>>;
  final hitMap = HitMap.parseJson(coverageJson);

  // wait for sample app to terminate.
  final exitCode = await sampleProcess.exitCode;
  if (exitCode != 0) {
    throw ProcessException(Platform.resolvedExecutable, sampleAppArgs,
        'Fatal error. Exit code: $exitCode', exitCode);
  }
  await sampleProcess.stderr.drain();
  return hitMap;
}
