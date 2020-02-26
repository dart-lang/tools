// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@deprecated
@TestOn('vm')
library package_config.discovery_analysis_test;

import "dart:async";
import "dart:io";

import "package:package_config/discovery_analysis.dart";
import "package:package_config/packages.dart";
import "package:path/path.dart" as path;
import "package:test/test.dart";

void main() {
  fileTest("basic", {
    ".packages": packagesFile,
    "foo": {".packages": packagesFile},
    "bar": {
      "packages": {"foo": {}, "bar": {}, "baz": {}}
    },
    "baz": {}
  }, (Directory directory) {
    var dirUri = Uri.directory(directory.path);
    var ctx = PackageContext.findAll(directory);
    var root = ctx[directory];
    expect(root, same(ctx));
    validatePackagesFile(root.packages, dirUri);
    var fooDir = sub(directory, "foo");
    var foo = ctx[fooDir];
    expect(identical(root, foo), isFalse);
    validatePackagesFile(foo.packages, dirUri.resolve("foo/"));
    var barDir = sub(directory, "bar");
    var bar = ctx[sub(directory, "bar")];
    validatePackagesDir(bar.packages, dirUri.resolve("bar/"));
    var barbar = ctx[sub(barDir, "bar")];
    expect(barbar, same(bar)); // inherited.
    var baz = ctx[sub(directory, "baz")];
    expect(baz, same(root)); // inherited.

    var map = ctx.asMap();
    expect(map.keys.map((dir) => dir.path),
        unorderedEquals([directory.path, fooDir.path, barDir.path]));
    return null;
  });
}

Directory sub(Directory parent, String dirName) {
  return Directory(path.join(parent.path, dirName));
}

const packagesFile = """
# A comment
foo:file:///dart/packages/foo/
bar:http://example.com/dart/packages/bar/
baz:packages/baz/
""";

void validatePackagesFile(Packages resolver, Uri location) {
  expect(resolver, isNotNull);
  expect(resolver.resolve(pkg("foo", "bar/baz")),
      equals(Uri.parse("file:///dart/packages/foo/bar/baz")));
  expect(resolver.resolve(pkg("bar", "baz/qux")),
      equals(Uri.parse("http://example.com/dart/packages/bar/baz/qux")));
  expect(resolver.resolve(pkg("baz", "qux/foo")),
      equals(location.resolve("packages/baz/qux/foo")));
  expect(resolver.packages, unorderedEquals(["foo", "bar", "baz"]));
}

void validatePackagesDir(Packages resolver, Uri location) {
  // Expect three packages: foo, bar and baz
  expect(resolver, isNotNull);
  expect(resolver.resolve(pkg("foo", "bar/baz")),
      equals(location.resolve("packages/foo/bar/baz")));
  expect(resolver.resolve(pkg("bar", "baz/qux")),
      equals(location.resolve("packages/bar/baz/qux")));
  expect(resolver.resolve(pkg("baz", "qux/foo")),
      equals(location.resolve("packages/baz/qux/foo")));
  if (location.scheme == "file") {
    expect(resolver.packages, unorderedEquals(["foo", "bar", "baz"]));
  } else {
    expect(() => resolver.packages, throwsUnsupportedError);
  }
}

Uri pkg(String packageName, String packagePath) {
  var path;
  if (packagePath.startsWith('/')) {
    path = "$packageName$packagePath";
  } else {
    path = "$packageName/$packagePath";
  }
  return Uri(scheme: "package", path: path);
}

/// Create a directory structure from [description] and run [fileTest].
///
/// Description is a map, each key is a file entry. If the value is a map,
/// it's a sub-dir, otherwise it's a file and the value is the content
/// as a string.
void fileTest(
    String name, Map description, Future fileTest(Directory directory)) {
  group("file-test", () {
    var tempDir = Directory.systemTemp.createTempSync("file-test");
    setUp(() {
      _createFiles(tempDir, description);
    });
    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    test(name, () => fileTest(tempDir));
  });
}

void _createFiles(Directory target, Map description) {
  description.forEach((name, content) {
    if (content is Map) {
      var subDir = Directory(path.join(target.path, name));
      subDir.createSync();
      _createFiles(subDir, content);
    } else {
      var file = File(path.join(target.path, name));
      file.writeAsStringSync(content, flush: true);
    }
  });
}
