// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('sdkPath', () {
    test('sdkPath', () {
      expect(sdkPath, isNotNull);
    });
  });

  group('applicationConfigHome', () {
    test('returns a non-empty string', () {
      expect(applicationConfigHome('dart'), isNotEmpty);
    });

    test('has an ancestor folder that exists', () {
      final path = p.split(applicationConfigHome('dart'));
      // We expect that first two segments of the path exist. This is really
      // just a dummy check that some part of the path exists.
      expect(Directory(p.joinAll(path.take(2))).existsSync(), isTrue);
    });

    test('empty environment throws exception', () async {
      expect(() {
        runZoned(() => applicationConfigHome('dart'), zoneValues: {
          #environmentOverrides: <String, String>{},
        });
      }, throwsA(isA<EnvironmentNotFoundException>()));
    });
  });
}
