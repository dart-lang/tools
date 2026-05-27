// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;

import 'package:checks/checks.dart';
import 'package:package_config/package_config_types.dart';
import 'package:test/scaffolding.dart';

import 'src/util.dart';

void main() {
  var unique = Object();
  var root = Uri.file('/tmp/root/');

  group('LanguageVersion', () {
    test('minimal', () {
      var version = LanguageVersion(3, 5);
      check(version.major).equals(3);
      check(version.minor).equals(5);
    });

    test('negative major', () {
      check(() => LanguageVersion(-1, 1))
          .throws<RangeError>()
          .has((e) => e.name, 'name')
          .isNotNull()
          .contains('major');
    });

    test('negative minor', () {
      check(() => LanguageVersion(1, -1))
          .throws<RangeError>()
          .has((e) => e.name, 'name')
          .isNotNull()
          .contains('minor');
    });

    test('minimal parse', () {
      var version = LanguageVersion.parse('3.5');
      check(version.major).equals(3);
      check(version.minor).equals(5);
    });

    void failParse(String name, String input) {
      test('$name - error', () {
        check(() => LanguageVersion.parse(input)).throws<PackageConfigError>();
        check(() => LanguageVersion.parse(input)).throws<FormatException>();
        var failed = false;
        var actual = LanguageVersion.parse(
          input,
          onError: (_) {
            failed = true;
          },
        );
        check(failed).isTrue();
        check(actual).isA<LanguageVersion>();
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

      for (var (otherVersion, checkCondition) in [
        (version, (Subject<int> s) => s.equals(0)), // Identical.
        (
          LanguageVersion(3, 5),
          (Subject<int> s) => s.equals(0),
        ), // Same major, same minor.
        (
          LanguageVersion(3, 4),
          (Subject<int> s) => s.isGreaterThan(0),
        ), // Same major, lower minor.
        (
          LanguageVersion(3, 6),
          (Subject<int> s) => s.isLessThan(0),
        ), // Same major, greater minor.
        (
          LanguageVersion(2, 5),
          (Subject<int> s) => s.isGreaterThan(0),
        ), // Lower major, same minor.
        (
          LanguageVersion(2, 4),
          (Subject<int> s) => s.isGreaterThan(0),
        ), // Lower major, lower minor.
        (
          LanguageVersion(2, 6),
          (Subject<int> s) => s.isGreaterThan(0),
        ), // Lower major, greater minor.
        (
          LanguageVersion(4, 5),
          (Subject<int> s) => s.isLessThan(0),
        ), // Greater major, same minor.
        (
          LanguageVersion(4, 4),
          (Subject<int> s) => s.isLessThan(0),
        ), // Greater major, lower minor.
        (
          LanguageVersion(4, 6),
          (Subject<int> s) => s.isLessThan(0),
        ), // Greater major, greater minor.
      ]) {
        checkCondition(check(version.compareTo(otherVersion)));
      }
    });

    test('compareTo invalid', () {
      var validVersion = LanguageVersion(3, 5);
      var invalidVersion = LanguageVersion.parse('', onError: (_) {});

      check(validVersion.compareTo(invalidVersion)).isGreaterThan(0);
      check(invalidVersion.compareTo(validVersion)).isLessThan(0);
    });

    test('relational valid', () {
      /// Test that the relational comparisons between two valid versions
      /// match the results of `compareTo`.
      void testComparisons(
        LanguageVersion version,
        LanguageVersion otherVersion,
      ) {
        check(
          version == otherVersion,
        ).equals(version.compareTo(otherVersion) == 0);

        check(
          version < otherVersion,
        ).equals(version.compareTo(otherVersion) < 0);
        check(
          version <= otherVersion,
        ).equals(version.compareTo(otherVersion) <= 0);

        check(
          version > otherVersion,
        ).equals(version.compareTo(otherVersion) > 0);
        check(
          version >= otherVersion,
        ).equals(version.compareTo(otherVersion) >= 0);
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
        check(version == otherVersion).equals(identical(version, otherVersion));

        check(() => version < otherVersion).throws<UnsupportedError>();
        check(() => version <= otherVersion).throws<UnsupportedError>();

        check(() => version > otherVersion).throws<UnsupportedError>();
        check(() => version >= otherVersion).throws<UnsupportedError>();
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
      check(package.name).equals('name');
      check(package.root).equals(root);
      check(package.packageUriRoot).equals(root);
      check(package.languageVersion).isNull();
      check(package.extraData).identicalTo(unique);
    });

    test('absolute package root', () {
      var version = LanguageVersion(1, 1);
      var absolute = root.resolve('foo/bar/');
      var package = Package(
        'name',
        root,
        packageUriRoot: absolute,
        relativeRoot: false,
        languageVersion: version,
        extraData: unique,
      );
      check(package.name).equals('name');
      check(package.root).equals(root);
      check(package.packageUriRoot).equals(absolute);
      check(package.languageVersion).equals(version);
      check(package.extraData).identicalTo(unique);
      check(package.relativeRoot).isFalse();
    });

    test('relative package root', () {
      var relative = Uri.parse('foo/bar/');
      var absolute = root.resolveUri(relative);
      var package = Package(
        'name',
        root,
        packageUriRoot: relative,
        relativeRoot: true,
        extraData: unique,
      );
      check(package.name).equals('name');
      check(package.root).equals(root);
      check(package.packageUriRoot).equals(absolute);
      check(package.relativeRoot).isTrue();
      check(package.languageVersion).isNull();
      check(package.extraData).identicalTo(unique);
    });

    for (var badName in ['a/z', 'a:z', '', '...']) {
      test("Invalid name '$badName'", () {
        check(() => Package(badName, root)).throws<PackageConfigError>();
      });
    }

    test('Invalid root, not absolute', () {
      check(
        () => Package('name', Uri.parse('/foo/')),
      ).throws<PackageConfigError>();
    });

    test('Invalid root, not ending in slash', () {
      check(
        () => Package('name', Uri.parse('file:///foo')),
      ).throws<PackageConfigError>();
    });

    test('invalid package root, not ending in slash', () {
      check(
        () => Package('name', root, packageUriRoot: Uri.parse('foo')),
      ).throws<PackageConfigError>();
    });

    test('invalid package root, not inside root', () {
      check(
        () => Package('name', root, packageUriRoot: Uri.parse('../baz/')),
      ).throws<PackageConfigError>();
    });
  });

  group('package config', () {
    test('empty', () {
      var empty = PackageConfig([], extraData: unique);
      check(empty.version).equals(2);
      check(empty.packages).isEmpty();
      check(empty.extraData).identicalTo(unique);
      check(empty.resolve(pkg('a', 'b'))).isNull();
    });

    test('single', () {
      var package = Package('name', root);
      var single = PackageConfig([package], extraData: unique);
      check(single.version).equals(2);
      check(single.packages).length.equals(1);
      check(single.extraData).identicalTo(unique);
      check(single.resolve(pkg('a', 'b'))).isNull();
      var resolved = single.resolve(pkg('name', 'a/b'));
      check(resolved).equals(root.resolve('a/b'));
    });
  });
  test('writeString', () {
    var config = PackageConfig(
      [
        Package(
          'foo',
          Uri.parse('file:///pkg/foo/'),
          packageUriRoot: Uri.parse('file:///pkg/foo/lib/'),
          relativeRoot: false,
          languageVersion: LanguageVersion(2, 4),
          extraData: {'foo': 'foo!'},
        ),
        Package(
          'bar',
          Uri.parse('file:///pkg/bar/'),
          packageUriRoot: Uri.parse('file:///pkg/bar/lib/'),
          relativeRoot: true,
          extraData: {'bar': 'bar!'},
        ),
      ],
      extraData: {'extra': 'data'},
    );
    var buffer = StringBuffer();
    PackageConfig.writeString(config, buffer, Uri.parse('file:///pkg/'));
    var text = buffer.toString();
    var json = jsonDecode(text); // Is valid JSON.
    check(json).isA<Map<String, dynamic>>()
      ..['configVersion'].equals(2)
      ..['extra'].equals('data')
      ..['packages'].isA<Iterable<Object?>>().unorderedMatches([
        (Subject<Object?> s) => s.isA<Map<Object?, Object?>>().deepEquals({
          'name': 'foo',
          'rootUri': 'file:///pkg/foo/',
          'packageUri': 'lib/',
          'languageVersion': '2.4',
          'foo': 'foo!',
        }),
        (Subject<Object?> s) => s.isA<Map<Object?, Object?>>().deepEquals({
          'name': 'bar',
          'rootUri': 'bar/',
          'packageUri': 'lib/',
          'bar': 'bar!',
        }),
      ]);
  });
}
