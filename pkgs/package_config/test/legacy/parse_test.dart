// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@deprecated
library package_config.parse_test;

import "package:package_config/packages.dart";
import "package:package_config/packages_file.dart" show parse;
import "package:package_config/src/packages_impl.dart";
import "package:test/test.dart";

void main() {
  var base = Uri.parse("file:///one/two/three/packages.map");
  test("empty", () {
    var packages = doParse(emptySample, base);
    expect(packages.asMap(), isEmpty);
  });
  test("comment only", () {
    var packages = doParse(commentOnlySample, base);
    expect(packages.asMap(), isEmpty);
  });
  test("empty lines only", () {
    var packages = doParse(emptyLinesSample, base);
    expect(packages.asMap(), isEmpty);
  });

  test("empty lines only", () {
    var packages = doParse(emptyLinesSample, base);
    expect(packages.asMap(), isEmpty);
  });

  test("single", () {
    var packages = doParse(singleRelativeSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("single no slash", () {
    var packages = doParse(singleRelativeSampleNoSlash, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("single no newline", () {
    var packages = doParse(singleRelativeSampleNoNewline, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("single absolute authority", () {
    var packages = doParse(singleAbsoluteSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(Uri.parse("http://example.com/some/where/bar/baz.dart")));
  });

  test("single empty path", () {
    var packages = doParse(singleEmptyPathSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.replace(path: "${base.path}/bar/baz.dart")));
  });

  test("single absolute path", () {
    var packages = doParse(singleAbsolutePathSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.replace(path: "/test/bar/baz.dart")));
  });

  test("multiple", () {
    var packages = doParse(multiRelativeSample, base);
    expect(packages.packages.toList()..sort(), equals(["bar", "foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
    expect(packages.resolve(Uri.parse("package:bar/foo/baz.dart")),
        equals(base.resolve("../test2/").resolve("foo/baz.dart")));
  });

  test("dot-dot 1", () {
    var packages = doParse(singleRelativeSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/qux/../bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("all valid chars can be used in URI segment", () {
    var packages = doParse(allValidCharsSample, base);
    expect(packages.packages.toList(), equals([allValidChars]));
    expect(packages.resolve(Uri.parse("package:$allValidChars/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("no invalid chars accepted", () {
    var map = {};
    for (var i = 0; i < allValidChars.length; i++) {
      map[allValidChars.codeUnitAt(i)] = true;
    }
    for (var i = 0; i <= 255; i++) {
      if (map[i] == true) continue;
      var char = String.fromCharCode(i);
      expect(() => doParse("x${char}x:x", null),
          anyOf(throwsNoSuchMethodError, throwsFormatException));
    }
  });

  test("no escapes", () {
    expect(() => doParse("x%41x:x", base), throwsFormatException);
  });

  test("same name twice", () {
    expect(
        () => doParse(singleRelativeSample * 2, base), throwsFormatException);
  });

  test("disallow default package", () {
    expect(() => doParse(":foo", base, allowDefaultPackage: false),
        throwsFormatException);
  });

  test("allow default package", () {
    var packages = doParse(":foo", base, allowDefaultPackage: true);
    expect(packages.defaultPackageName, "foo");
  });

  test("allow default package name with dot", () {
    var packages = doParse(":foo.bar", base, allowDefaultPackage: true);
    expect(packages.defaultPackageName, "foo.bar");
  });

  test("not two default packages", () {
    expect(() => doParse(":foo\n:bar", base, allowDefaultPackage: true),
        throwsFormatException);
  });

  test("default package invalid package name", () {
    // Not a valid *package name*.
    expect(() => doParse(":foo/bar", base, allowDefaultPackage: true),
        throwsFormatException);
  });

  group("metadata", () {
    var packages = doParse(
        ":foo\n"
        "foo:foo#metafoo=1\n"
        "bar:bar#metabar=2\n"
        "baz:baz\n"
        "qux:qux#metaqux1=3&metaqux2=4\n",
        base,
        allowDefaultPackage: true);
    test("non-existing", () {
      // non-package name.
      expect(packages.packageMetadata("///", "f"), null);
      expect(packages.packageMetadata("", "f"), null);
      // unconfigured package name.
      expect(packages.packageMetadata("absent", "f"), null);
      // package name without that metadata
      expect(packages.packageMetadata("foo", "notfoo"), null);
    });
    test("lookup", () {
      expect(packages.packageMetadata("foo", "metafoo"), "1");
      expect(packages.packageMetadata("bar", "metabar"), "2");
      expect(packages.packageMetadata("qux", "metaqux1"), "3");
      expect(packages.packageMetadata("qux", "metaqux2"), "4");
    });
    test("by library URI", () {
      expect(
          packages.libraryMetadata(
              Uri.parse("package:foo/index.dart"), "metafoo"),
          "1");
      expect(
          packages.libraryMetadata(
              Uri.parse("package:bar/index.dart"), "metabar"),
          "2");
      expect(
          packages.libraryMetadata(
              Uri.parse("package:qux/index.dart"), "metaqux1"),
          "3");
      expect(
          packages.libraryMetadata(
              Uri.parse("package:qux/index.dart"), "metaqux2"),
          "4");
    });
    test("by default package", () {
      expect(
          packages.libraryMetadata(
              Uri.parse("file:///whatever.dart"), "metafoo"),
          "1");
    });
  });

  for (var invalidSample in invalid) {
    test("invalid '$invalidSample'", () {
      var result;
      try {
        result = doParse(invalidSample, base);
      } on FormatException {
        // expected
        return;
      }
      fail("Resolved to $result");
    });
  }
}

Packages doParse(String sample, Uri baseUri,
    {bool allowDefaultPackage = false}) {
  var map = parse(sample.codeUnits, baseUri,
      allowDefaultPackage: allowDefaultPackage);
  return MapPackages(map);
}

// Valid samples.
var emptySample = "";
var commentOnlySample = "# comment only\n";
var emptyLinesSample = "\n\n\r\n";
var singleRelativeSample = "foo:../test/\n";
var singleRelativeSampleNoSlash = "foo:../test\n";
var singleRelativeSampleNoNewline = "foo:../test/";
var singleAbsoluteSample = "foo:http://example.com/some/where/\n";
var singleEmptyPathSample = "foo:\n";
var singleAbsolutePathSample = "foo:/test/\n";
var multiRelativeSample = "foo:../test/\nbar:../test2/\n";
// All valid path segment characters in an URI.
var allValidChars = r"!$&'()*+,-.0123456789;="
    r"@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~";

var allValidCharsSample = "${allValidChars}:../test/\n";

// Invalid samples.
var invalid = [
  ":baz.dart", // empty.
  "foobar=baz.dart", // no colon (but an equals, which is not the same)
  ".:../test/", // dot segment
  "..:../test/", // dot-dot segment
  "...:../test/", // dot-dot-dot segment
  "foo/bar:../test/", // slash in name
  "/foo:../test/", // slash at start of name
  "?:../test/", // invalid characters.
  "[:../test/", // invalid characters.
  "x#:../test/", // invalid characters.
];
