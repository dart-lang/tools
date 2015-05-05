// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pub_semver.test.version_range_test;

import 'package:test/test.dart';

import 'package:pub_semver/pub_semver.dart';

import 'utils.dart';

main() {
  group('constructor', () {
    test('takes a min and max', () {
      var range = new VersionRange(min: v123, max: v124);
      expect(range.isAny, isFalse);
      expect(range.min, equals(v123));
      expect(range.max, equals(v124));
    });

    test('allows omitting max', () {
      var range = new VersionRange(min: v123);
      expect(range.isAny, isFalse);
      expect(range.min, equals(v123));
      expect(range.max, isNull);
    });

    test('allows omitting min and max', () {
      var range = new VersionRange();
      expect(range.isAny, isTrue);
      expect(range.min, isNull);
      expect(range.max, isNull);
    });

    test('takes includeMin', () {
      var range = new VersionRange(min: v123, includeMin: true);
      expect(range.includeMin, isTrue);
    });

    test('includeMin defaults to false if omitted', () {
      var range = new VersionRange(min: v123);
      expect(range.includeMin, isFalse);
    });

    test('takes includeMax', () {
      var range = new VersionRange(max: v123, includeMax: true);
      expect(range.includeMax, isTrue);
    });

    test('includeMax defaults to false if omitted', () {
      var range = new VersionRange(max: v123);
      expect(range.includeMax, isFalse);
    });

    test('throws if min > max', () {
      expect(() => new VersionRange(min: v124, max: v123), throwsArgumentError);
    });
  });

  group('allows()', () {
    test('version must be greater than min', () {
      var range = new VersionRange(min: v123);

      expect(range, allows(
          new Version.parse('1.3.3'),
          new Version.parse('2.3.3')));
      expect(range, doesNotAllow(
          new Version.parse('1.2.2'),
          new Version.parse('1.2.3')));
    });

    test('version must be min or greater if includeMin', () {
      var range = new VersionRange(min: v123, includeMin: true);

      expect(range, allows(
          new Version.parse('1.2.3'),
          new Version.parse('1.3.3'),
          new Version.parse('2.3.3')));
      expect(range, doesNotAllow(new Version.parse('1.2.2')));
    });

    test('pre-release versions of inclusive min are excluded', () {
      var range = new VersionRange(min: v123, includeMin: true);

      expect(range, allows(new Version.parse('1.2.4-dev')));
      expect(range, doesNotAllow(new Version.parse('1.2.3-dev')));
    });

    test('version must be less than max', () {
      var range = new VersionRange(max: v234);

      expect(range, allows(new Version.parse('2.3.3')));
      expect(range, doesNotAllow(
          new Version.parse('2.3.4'),
          new Version.parse('2.4.3')));
    });

    test('pre-release versions of non-pre-release max are excluded', () {
      var range = new VersionRange(max: v234);

      expect(range, allows(new Version.parse('2.3.3')));
      expect(range, doesNotAllow(
          new Version.parse('2.3.4-dev'),
          new Version.parse('2.3.4')));
    });

    test('pre-release versions of pre-release max are included', () {
      var range = new VersionRange(max: new Version.parse('2.3.4-dev.2'));

      expect(range, allows(
          new Version.parse('2.3.4-dev.1')));
      expect(range, doesNotAllow(
          new Version.parse('2.3.4-dev.2'),
          new Version.parse('2.3.4-dev.3')));
    });

    test('version must be max or less if includeMax', () {
      var range = new VersionRange(min: v123, max: v234, includeMax: true);

      expect(range, allows(
          new Version.parse('2.3.3'),
          new Version.parse('2.3.4'),
          // Pre-releases of the max are allowed.
          new Version.parse('2.3.4-dev')));
      expect(range, doesNotAllow(new Version.parse('2.4.3')));
    });

    test('has no min if one was not set', () {
      var range = new VersionRange(max: v123);

      expect(range, allows(new Version.parse('0.0.0')));
      expect(range, doesNotAllow(new Version.parse('1.2.3')));
    });

    test('has no max if one was not set', () {
      var range = new VersionRange(min: v123);

      expect(range, allows(
          new Version.parse('1.3.3'),
          new Version.parse('999.3.3')));
      expect(range, doesNotAllow(new Version.parse('1.2.3')));
    });

    test('allows any version if there is no min or max', () {
      var range = new VersionRange();

      expect(range, allows(
          new Version.parse('0.0.0'),
          new Version.parse('999.99.9')));
    });
  });

  group('intersect()', () {
    test('two overlapping ranges', () {
      var a = new VersionRange(min: v123, max: v250);
      var b = new VersionRange(min: v200, max: v300);
      var intersect = a.intersect(b);
      expect(intersect.min, equals(v200));
      expect(intersect.max, equals(v250));
      expect(intersect.includeMin, isFalse);
      expect(intersect.includeMax, isFalse);
    });

    test('a non-overlapping range allows no versions', () {
      var a = new VersionRange(min: v114, max: v124);
      var b = new VersionRange(min: v200, max: v250);
      expect(a.intersect(b).isEmpty, isTrue);
    });

    test('adjacent ranges allow no versions if exclusive', () {
      var a = new VersionRange(min: v114, max: v124, includeMax: false);
      var b = new VersionRange(min: v124, max: v200, includeMin: true);
      expect(a.intersect(b).isEmpty, isTrue);
    });

    test('adjacent ranges allow version if inclusive', () {
      var a = new VersionRange(min: v114, max: v124, includeMax: true);
      var b = new VersionRange(min: v124, max: v200, includeMin: true);
      expect(a.intersect(b), equals(v124));
    });

    test('with an open range', () {
      var open = new VersionRange();
      var a = new VersionRange(min: v114, max: v124);
      expect(open.intersect(open), equals(open));
      expect(a.intersect(open), equals(a));
    });

    test('returns the version if the range allows it', () {
      expect(new VersionRange(min: v114, max: v124).intersect(v123),
          equals(v123));
      expect(new VersionRange(min: v123, max: v124).intersect(v114).isEmpty,
          isTrue);
    });
  });

  test('isEmpty', () {
    expect(new VersionRange().isEmpty, isFalse);
    expect(new VersionRange(min: v123, max: v124).isEmpty, isFalse);
  });
}
