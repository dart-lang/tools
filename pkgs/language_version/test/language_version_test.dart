// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:language_version/language_version.dart';
import 'package:test/test.dart';

void main() {
  group('default implementation', () {
    test('retains major and minor values', () {
      const dartThreeFive = LanguageVersion.of(3, 5);
      expect(dartThreeFive.major, equals(3));
      expect(dartThreeFive.minor, equals(5));
    });

    test('outputs formatted string', () {
      const dartTwoTwelve = LanguageVersion.of(2, 12);
      expect(dartTwoTwelve.toString(), '2.12');
    });
  });
}
