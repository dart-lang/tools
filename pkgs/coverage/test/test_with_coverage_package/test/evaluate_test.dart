// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../lib/validate_lib.dart';
import 'package:test/test.dart';

void main() {
  group('evaluateScore', () {
    test('returns Invalid for negative score', () {
      expect(evaluateScore(-10), equals('Invalid'));
    });

    test('returns Fail for score < 50', () {
      expect(evaluateScore(30), equals('Fail'));
    });

    test('returns Excellent for score 85', () {
      expect(evaluateScore(85), equals('Excellent'));
    });
  });
}
