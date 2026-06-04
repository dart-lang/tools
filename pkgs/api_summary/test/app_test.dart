// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout.factor(3)
library;

import 'dart:convert';
import 'dart:io';
import 'package:api_summary/api_summary.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String jsonSummary;
  late String textSummary;

  setUpAll(() async {
    final apiPackage = await apiSummary(_pkgDir());

    jsonSummary = const JsonEncoder.withIndent(
      '  ',
    ).convert(apiPackage.toJson());
    textSummary = apiPackage.toString();
  });

  test('json output matches api.json', () {
    _verifyGolden(jsonSummary, 'api.json');
  });

  test('text output matches api.txt', () {
    _verifyGolden(textSummary, 'api.txt');
  });

  test('rehydrated json renders identical text summary', () {
    final parsed = jsonDecode(jsonSummary) as Map<String, dynamic>;
    final apiPackage = ApiSummary.fromJson(parsed);
    final renderedText = apiPackage.toString();

    expect(renderedText, equals(textSummary));
  });
}

void _verifyGolden(String actual, String goldenFileName) {
  final goldenFile = File(p.join(_pkgDir(), goldenFileName));
  final expectedText = LineSplitter.split(
    goldenFile.readAsStringSync(),
  ).join('\n');
  final actualText = LineSplitter.split(actual).join('\n');

  expect(actualText, equals(expectedText));
}

// Dynamically locate the api_summary package root
String _pkgDir() {
  var packageDir = p.normalize(p.absolute(Directory.current.path));
  if (!_isApiSummaryDir(packageDir)) {
    // We might be running from the SDK root
    final candidate = p.join(packageDir, 'pkg', 'api_summary');
    if (_isApiSummaryDir(candidate)) {
      packageDir = candidate;
    }
  }

  return packageDir;
}

bool _isApiSummaryDir(String dir) {
  final pubspec = File(p.join(dir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  return pubspec.readAsStringSync().contains('name: api_summary');
}
