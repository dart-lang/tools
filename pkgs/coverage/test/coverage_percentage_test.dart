// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:coverage/src/coverage_percentage.dart';
import 'package:coverage/src/hitmap.dart';
import 'package:test/test.dart';

void main() {
  group('calculateCoveragePercentage', () {
    test('calculates correct percentage', () {
      final hitmap = {
        'file1.dart': HitMap({
          1: 1, // covered
          2: 1, // covered
          3: 0, // not covered
          4: 1, // covered
        }),
        'file2.dart': HitMap({
          1: 1, // covered
          2: 0, // not covered
          3: 0, // not covered
        }),
      };

      final result = calculateCoveragePercentage(hitmap);

      // 4 covered lines out of 7 total lines = 57.14%
      expect(result.percentage.toStringAsFixed(2), equals('57.14'));
      expect(result.coveredLines, equals(4));
      expect(result.totalLines, equals(7));
    });
    test('handles empty hitmap', () {
      final hitmap = <String, HitMap>{};

      final result = calculateCoveragePercentage(hitmap);

      expect(result.percentage, equals(0));
      expect(result.coveredLines, equals(0));
      expect(result.totalLines, equals(0));
    });

    test('handles hitmap with no covered lines', () {
      final hitmap = {
        'file1.dart': HitMap({
          1: 0, // not covered
          2: 0, // not covered
          3: 0, // not covered
        }),
      };

      final result = calculateCoveragePercentage(hitmap);

      expect(result.percentage, equals(0));
      expect(result.coveredLines, equals(0));
      expect(result.totalLines, equals(3));
    });

    test('handles hitmap with all lines covered', () {
      final hitmap = {
        'file1.dart': HitMap({
          1: 1, // covered
          2: 1, // covered
          3: 1, // covered
        }),
      };

      final result = calculateCoveragePercentage(hitmap);

      expect(result.percentage, equals(100));
      expect(result.coveredLines, equals(3));
      expect(result.totalLines, equals(3));
    });
    test('includes branch hits in coverage percentage', () {
      // 2 lines (1 covered) + 3 branches (2 covered) = 5 total, 3 covered
      final hitmap = {
        'file.dart': HitMap(
          {1: 1, 2: 0}, // lineHits
          null,
          null,
          {10: 1, 11: 0, 12: 2}, // branchHits
        ),
      };
      final result = calculateCoveragePercentage(hitmap);

      expect(result.totalLines, equals(5));
      expect(result.coveredLines, equals(3));
      expect(result.percentage.toStringAsFixed(2), equals('60.00'));
    });
  });
}
