// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test_all;

import "package:package_config/packages.dart";
import "package:package_config/packages_file.dart" show parse;
import "package:test/test.dart";

main() {
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

  test("single absolute", () {
    var packages = doParse(singleAbsoluteSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:foo/bar/baz.dart")),
        equals(Uri.parse("http://example.com/some/where/bar/baz.dart")));
  });

  test("multiple", () {
    var packages = doParse(multiRelativeSample, base);
    expect(
        packages.packages.toList()..sort(), equals(["bar", "foo"]));
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

  test("dot-dot 2", () {
    var packages = doParse(singleRelativeSample, base);
    expect(packages.packages.toList(), equals(["foo"]));
    expect(packages.resolve(Uri.parse("package:qux/../foo/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("all valid chars", () {
    var packages = doParse(allValidCharsSample, base);
    expect(packages.packages.toList(), equals([allValidChars]));
    expect(packages.resolve(Uri.parse("package:$allValidChars/bar/baz.dart")),
        equals(base.resolve("../test/").resolve("bar/baz.dart")));
  });

  test("no escapes", () {
    expect(() => doParse("x%41x=x", base), throws);
  });

  test("not identifiers", () {
    expect(() => doParse("1x=x", base), throws);
    expect(() => doParse(" x=x", base), throws);
    expect(() => doParse("\\x41x=x", base), throws);
    expect(() => doParse("x@x=x", base), throws);
    expect(() => doParse("x[x=x", base), throws);
    expect(() => doParse("x`x=x", base), throws);
    expect(() => doParse("x{x=x", base), throws);
    expect(() => doParse("x/x=x", base), throws);
    expect(() => doParse("x:x=x", base), throws);
  });

  test("same name twice", () {
    expect(() => doParse(singleRelativeSample * 2, base), throws);
  });

  for (String invalidSample in invalid) {
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

Packages doParse(String sample, Uri baseUri) {
  Map<String, Uri> map = parse(sample.codeUnits, baseUri);
  return new Packages(map);
}

// Valid samples.
var emptySample = "";
var commentOnlySample = "# comment only\n";
var emptyLinesSample = "\n\n\r\n";
var singleRelativeSample = "foo=../test/\n";
var singleRelativeSampleNoSlash = "foo=../test\n";
var singleRelativeSampleNoNewline = "foo=../test/";
var singleAbsoluteSample = "foo=http://example.com/some/where/\n";
var multiRelativeSample = "foo=../test/\nbar=../test2/\n";
// All valid path segment characters in an URI.
var allValidChars =
    r"$0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";
var allValidCharsSample = "${allValidChars.replaceAll('=', '%3D')}=../test/\n";
var allUnreservedChars =
    "-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~";

// Invalid samples.
var invalid = [
  "foobar:baz.dart", // no equals
  ".=../test/", // dot segment
  "..=../test/", // dot-dot segment
  "foo/bar=../test/", //
  "/foo=../test/", // var multiSegmentSample
  "?=../test/", // invalid characters in path segment.
  "[=../test/", // invalid characters in path segment.
  "x#=../test/", // invalid characters in path segment.
];
