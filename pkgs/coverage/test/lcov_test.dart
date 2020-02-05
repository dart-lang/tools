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

    expect(sampleAppHitMap, containsPair(44, greaterThanOrEqualTo(1)),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitMap, containsPair(48, 0),
        reason: 'be careful if you modify the test file');
    expect(sampleAppHitMap, isNot(contains(30)),
        reason: 'be careful if you modify the test file');
  });

  group('LcovFormatter', () {
    test('format()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter = LcovFormatter(resolver);

      final res = await formatter.format(hitmap);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('format() includes files in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter = LcovFormatter(resolver, reportOn: ['lib/', 'test/']);

      final res = await formatter.format(hitmap);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('format() excludes files not in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter = LcovFormatter(resolver, reportOn: ['lib/']);

      final res = await formatter.format(hitmap);

      expect(res, isNot(contains(p.absolute(_sampleAppPath))));
      expect(res, isNot(contains(p.absolute(_isolateLibPath))));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('format() uses paths relative to basePath', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter = LcovFormatter(resolver, basePath: p.absolute('lib'));

      final res = await formatter.format(hitmap);

      expect(
          res, isNot(contains(p.absolute(p.join('lib', 'src', 'util.dart')))));
      expect(res, contains(p.join('src', 'util.dart')));
    });
  });

  group('PrettyPrintFormatter', () {
    test('format()', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter = PrettyPrintFormatter(resolver, Loader());

      final res = await formatter.format(hitmap);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));

      // be very careful if you change the test file
      expect(res, contains('      0|  return a - b;'));

      expect(res, contains('|  return _withTimeout(() async {'),
          reason: 'be careful if you change lib/src/util.dart');

      final hitLineRegexp = RegExp(r'\s+(\d+)\|  return a \+ b;');
      final match = hitLineRegexp.allMatches(res).single;

      final hitCount = int.parse(match[1]);
      expect(hitCount, greaterThanOrEqualTo(1));
    });

    test('format() includes files in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter =
          PrettyPrintFormatter(resolver, Loader(), reportOn: ['lib/', 'test/']);

      final res = await formatter.format(hitmap);

      expect(res, contains(p.absolute(_sampleAppPath)));
      expect(res, contains(p.absolute(_isolateLibPath)));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });

    test('format() excludes files not in reportOn list', () async {
      final hitmap = await _getHitMap();

      final resolver = Resolver(packagesPath: '.packages');
      final formatter =
          PrettyPrintFormatter(resolver, Loader(), reportOn: ['lib/']);

      final res = await formatter.format(hitmap);

      expect(res, isNot(contains(p.absolute(_sampleAppPath))));
      expect(res, isNot(contains(p.absolute(_isolateLibPath))));
      expect(res, contains(p.absolute(p.join('lib', 'src', 'util.dart'))));
    });
  });
}

Future<Map<String, Map<int, int>>> _getHitMap() async {
  expect(FileSystemEntity.isFileSync(_sampleAppPath), isTrue);

  // select service port.
  final port = await getOpenPort();

  // start sample app.
  final sampleAppArgs = [
    '--pause-isolates-on-exit',
    '--enable-vm-service=$port',
    _sampleAppPath
  ];
  final sampleProcess = await Process.start('dart', sampleAppArgs);

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

  // collect hit map.
  final coverageJson =
      (await collect(serviceUri, true, true, false, <String>{}))['coverage']
          as List<Map<String, dynamic>>;
  final hitMap = createHitmap(coverageJson);

  // wait for sample app to terminate.
  final exitCode = await sampleProcess.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
        'dart', sampleAppArgs, 'Fatal error. Exit code: $exitCode', exitCode);
  }
  await sampleProcess.stderr.drain<List<int>>();
  return hitMap;
}
