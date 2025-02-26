// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;

import 'package:package_config/package_config_types.dart';
import 'package:test/test.dart';
import 'src/util.dart';

void main() {
  var unique = Object();
  var root = Uri.file('/tmp/root/');

  group('LanguageVersion', () {
    test('minimal', () {
      var version = LanguageVersion(3, 5);
      expect(version.major, 3);
      expect(version.minor, 5);
    });

    test('negative major', () {
      expect(
          () => LanguageVersion(-1, 1),
          throwsA(isA<RangeError>().having(
            (e) => e.name,
            'message',
            contains('major'),
          )));
    });

    test('negative minor', () {
      expect(
          () => LanguageVersion(1, -1),
          throwsA(isA<RangeError>().having(
            (e) => e.name,
            'message',
            contains('minor'),
          )));
    });

    test('minimal parse', () {
      var version = LanguageVersion.parse('3.5');
      expect(version.major, 3);
      expect(version.minor, 5);
    });

    void failParse(String name, String input) {
      test('$name - error', () {
        expect(() => LanguageVersion.parse(input),
            throwsA(isA<PackageConfigError>()));
        expect(() => LanguageVersion.parse(input), throwsFormatException);
        var failed = false;
        var actual = LanguageVersion.parse(input, onError: (_) {
          failed = true;
        });
        expect(failed, true);
        expect(actual, isA<LanguageVersion>());
      });
    }

    failParse('Leading zero major', '01.1');
    failParse('Leading zero minor', '1.01');
    failParse('Sign+ major', '+1.1');
    failParse('Sign- major', '-1.1');
    failParse('Sign+ minor', '1.+1');
    failParse('Sign- minor', '1.-1');
    failParse('WhiteSpace 1', ' 1.1');
    failParse('WhiteSpace 2', '1 .1');
    failParse('WhiteSpace 3', '1. 1');
    failParse('WhiteSpace 4', '1.1 ');

    test('compareTo valid', () {
      var version = LanguageVersion(3, 5);

      for (var (otherVersion, matcher) in [
        (version, isZero), // Identical.
        (LanguageVersion(3, 5), isZero), // Same major, same minor.
        (LanguageVersion(3, 4), isPositive), // Same major, lower minor.
        (LanguageVersion(3, 6), isNegative), // Same major, greater minor.
        (LanguageVersion(2, 5), isPositive), // Lower major, same minor.
        (LanguageVersion(2, 4), isPositive), // Lower major, lower minor.
        (LanguageVersion(2, 6), isPositive), // Lower major, greater minor.
        (LanguageVersion(4, 5), isNegative), // Greater major, same minor.
        (LanguageVersion(4, 4), isNegative), // Greater major, lower minor.
        (LanguageVersion(4, 6), isNegative), // Greater major, greater minor.
      ]) {
        expect(version.compareTo(otherVersion), matcher);
      }
    });

    test('compareTo invalid', () {
      var validVersion = LanguageVersion(3, 5);
      var invalidVersion = LanguageVersion.parse('', onError: (_) {});

      expect(validVersion.compareTo(invalidVersion), isPositive);
      expect(invalidVersion.compareTo(validVersion), isNegative);
    });

    test('relational valid', () {
      /// Test that the relational comparisons between two valid versions
      /// match the results of `compareTo`.
      void testComparisons(
          LanguageVersion version, LanguageVersion otherVersion) {
        expect(version == otherVersion, version.compareTo(otherVersion) == 0);

        expect(version < otherVersion, version.compareTo(otherVersion) < 0);
        expect(version <= otherVersion, version.compareTo(otherVersion) <= 0);

        expect(version > otherVersion, version.compareTo(otherVersion) > 0);
        expect(version >= otherVersion, version.compareTo(otherVersion) >= 0);
      }

      var version = LanguageVersion(3, 5);

      // Check relational comparisons of a version to itself.
      testComparisons(version, version);

      // Check relational comparisons of a version to versions with all
      // possible combinations of minor and major versions that are
      // the same, lower, and greater.
      for (final major in [2, 3, 4]) {
        for (final minor in [4, 5, 6]) {
          testComparisons(version, LanguageVersion(major, minor));
        }
      }
    });

    test('relational invalid', () {
      void testComparisonsWithInvalid(
        LanguageVersion version,
        LanguageVersion otherVersion,
      ) {
        expect(version == otherVersion, identical(version, otherVersion));

        expect(() => version < otherVersion, throwsA(isA<StateError>()));
        expect(() => version <= otherVersion, throwsA(isA<StateError>()));

        expect(() => version > otherVersion, throwsA(isA<StateError>()));
        expect(() => version >= otherVersion, throwsA(isA<StateError>()));
      }

      var validVersion = LanguageVersion(3, 5);
      var invalidVersion = LanguageVersion.parse('', onError: (_) {});
      var differentInvalidVersion = LanguageVersion.parse('-', onError: (_) {});

      testComparisonsWithInvalid(validVersion, invalidVersion);
      testComparisonsWithInvalid(invalidVersion, validVersion);
      testComparisonsWithInvalid(invalidVersion, invalidVersion);
      testComparisonsWithInvalid(invalidVersion, differentInvalidVersion);
    });
  });

  group('Package', () {
    test('minimal', () {
      var package = Package('name', root, extraData: unique);
      expect(package.name, 'name');
      expect(package.root, root);
      expect(package.packageUriRoot, root);
      expect(package.languageVersion, null);
      expect(package.extraData, same(unique));
    });

    test('absolute package root', () {
      var version = LanguageVersion(1, 1);
      var absolute = root.resolve('foo/bar/');
      var package = Package('name', root,
          packageUriRoot: absolute,
          relativeRoot: false,
          languageVersion: version,
          extraData: unique);
      expect(package.name, 'name');
      expect(package.root, root);
      expect(package.packageUriRoot, absolute);
      expect(package.languageVersion, version);
      expect(package.extraData, same(unique));
      expect(package.relativeRoot, false);
    });

    test('relative package root', () {
      var relative = Uri.parse('foo/bar/');
      var absolute = root.resolveUri(relative);
      var package = Package('name', root,
          packageUriRoot: relative, relativeRoot: true, extraData: unique);
      expect(package.name, 'name');
      expect(package.root, root);
      expect(package.packageUriRoot, absolute);
      expect(package.relativeRoot, true);
      expect(package.languageVersion, null);
      expect(package.extraData, same(unique));
    });

    for (var badName in ['a/z', 'a:z', '', '...']) {
      test("Invalid name '$badName'", () {
        expect(() => Package(badName, root), throwsPackageConfigError);
      });
    }

    test('Invalid root, not absolute', () {
      expect(
          () => Package('name', Uri.parse('/foo/')), throwsPackageConfigError);
    });

    test('Invalid root, not ending in slash', () {
      expect(() => Package('name', Uri.parse('file:///foo')),
          throwsPackageConfigError);
    });

    test('invalid package root, not ending in slash', () {
      expect(() => Package('name', root, packageUriRoot: Uri.parse('foo')),
          throwsPackageConfigError);
    });

    test('invalid package root, not inside root', () {
      expect(() => Package('name', root, packageUriRoot: Uri.parse('../baz/')),
          throwsPackageConfigError);
    });
  });

  group('package config', () {
    test('empty', () {
      var empty = PackageConfig([], extraData: unique);
      expect(empty.version, 2);
      expect(empty.packages, isEmpty);
      expect(empty.extraData, same(unique));
      expect(empty.resolve(pkg('a', 'b')), isNull);
    });

    test('single', () {
      var package = Package('name', root);
      var single = PackageConfig([package], extraData: unique);
      expect(single.version, 2);
      expect(single.packages, hasLength(1));
      expect(single.extraData, same(unique));
      expect(single.resolve(pkg('a', 'b')), isNull);
      var resolved = single.resolve(pkg('name', 'a/b'));
      expect(resolved, root.resolve('a/b'));
    });
  });
  test('writeString', () {
    var config = PackageConfig([
      Package('foo', Uri.parse('file:///pkg/foo/'),
          packageUriRoot: Uri.parse('file:///pkg/foo/lib/'),
          relativeRoot: false,
          languageVersion: LanguageVersion(2, 4),
          extraData: {'foo': 'foo!'}),
      Package('bar', Uri.parse('file:///pkg/bar/'),
          packageUriRoot: Uri.parse('file:///pkg/bar/lib/'),
          relativeRoot: true,
          extraData: {'bar': 'bar!'}),
    ], extraData: {
      'extra': 'data'
    });
    var buffer = StringBuffer();
    PackageConfig.writeString(config, buffer, Uri.parse('file:///pkg/'));
    var text = buffer.toString();
    var json = jsonDecode(text); // Is valid JSON.
    expect(json, {
      'configVersion': 2,
      'packages': unorderedEquals([
        {
          'name': 'foo',
          'rootUri': 'file:///pkg/foo/',
          'packageUri': 'lib/',
          'languageVersion': '2.4',
          'foo': 'foo!',
        },
        {
          'name': 'bar',
          'rootUri': 'bar/',
          'packageUri': 'lib/',
          'bar': 'bar!',
        },
      ]),
      'extra': 'data',
    });
  });
}

final Matcher throwsPackageConfigError = throwsA(isA<PackageConfigError>());
