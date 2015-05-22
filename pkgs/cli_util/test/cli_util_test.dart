// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cli_util/cli_util.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('getSdkDir', () {
    test('arg parsing', () {
      expect(getSdkDir(['--dart-sdk', '/dart/sdk']).path, equals('/dart/sdk'));
      expect(getSdkDir(['--dart-sdk=/dart/sdk']).path, equals('/dart/sdk'));
    });
    test('finds the SDK without cli args', () {
      expect(getSdkDir(), isNotNull);
    });
  });
}

main() {
  groupSep = ' | ';

  defineTests();
}
