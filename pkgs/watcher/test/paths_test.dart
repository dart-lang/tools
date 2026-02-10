// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:watcher/src/paths.dart';

void main() {
  final separator = Platform.pathSeparator;

  group('AbsolutePath', () {
    test('tryRelativeTo extracts path segment', () {
      expect(
        AbsolutePath(
          'a${separator}b${separator}c',
        ).tryRelativeTo(AbsolutePath('a${separator}b')),
        'c',
      );
    });

    test('tryRelativeTo extracts many path segments', () {
      expect(
        AbsolutePath(
          'a${separator}b${separator}c${separator}d',
        ).tryRelativeTo(AbsolutePath('a${separator}b')),
        'c${separator}d',
      );
    });

    test('tryRelativeTo checks for final separator', () {
      expect(
        AbsolutePath(
          'a${separator}bbc',
        ).tryRelativeTo(AbsolutePath('a${separator}b')),
        null,
      );
    });
  });
}
