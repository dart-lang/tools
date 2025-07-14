// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final baseDirectories = BaseDirectories('my_app');

  test('returns a non-empty string', () {
    expect(baseDirectories.cacheHome, isNotEmpty);
    expect(baseDirectories.configHome, isNotEmpty);
    expect(baseDirectories.dataHome, isNotEmpty);
    expect(baseDirectories.runtimeHome, isNotEmpty);
    expect(baseDirectories.stateHome, isNotEmpty);
  });

  test('has an ancestor folder that exists', () {
    void expectAncestorExists(String path) {
      // We expect that first two segments of the path exist. This is really
      // just a dummy check that some part of the path exists.
      final ancestorPath = p.joinAll(p.split(path).take(2));
      expect(
        Directory(ancestorPath).existsSync(),
        isTrue,
      );
    }

    expectAncestorExists(baseDirectories.cacheHome);
    expectAncestorExists(baseDirectories.configHome);
    expectAncestorExists(baseDirectories.dataHome);
    expectAncestorExists(baseDirectories.runtimeHome);
    expectAncestorExists(baseDirectories.stateHome);
  });

  test('empty environment throws exception', () async {
    expect(
      () => BaseDirectories('Dart', environment: <String, String>{}).configHome,
      throwsA(isA<EnvironmentNotFoundException>()),
    );
  });
}
