// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import "dart:io";
import 'dart:typed_data';

import "package:test/test.dart";
import "package:package_config/src/util.dart";

/// Creates a directory structure from [description] and runs [fileTest].
///
/// Description is a map, each key is a file entry. If the value is a map,
/// it's a subdirectory, otherwise it's a file and the value is the content
/// as a string.
/// Introduces a group to hold the [setUp]/[tearDown] logic.
void fileTest(String name, Map<String, Object> description,
    void fileTest(Directory directory)) {
  group("file-test", () {
    Directory tempDir = Directory.systemTemp.createTempSync("pkgcfgtest");
    setUp(() {
      _createFiles(tempDir, description);
    });
    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    test(name, () => fileTest(tempDir));
  });
}

/// Creates a set of files under a new temporary directory.
/// Returns the temporary directory.
///
/// The [description] is a map from file names to content.
/// If the content is again a map, it represents a subdirectory
/// with the content as description.
/// Otherwise the content should be a string,
/// which is written to the file as UTF-8.
Directory createTestFiles(Map<String, Object> description) {
  var target = Directory.systemTemp.createTempSync("pkgcfgtest");
  _createFiles(target, description);
  return target;
}

// Creates temporary files in the target directory.
void _createFiles(Directory target, Map<Object, Object> description) {
  description.forEach((name, content) {
    var entryName = pathJoin(target.path, "$name");
    if (content is Map<Object, Object>) {
      _createFiles(Directory(entryName)..createSync(), content);
    } else {
      File(entryName).writeAsStringSync(content, flush: true);
    }
  });
}

/// Creates a [Directory] for a subdirectory of [parent].
Directory subdir(Directory parent, String dirName) =>
    Directory(pathJoinAll([parent.path, ...dirName.split("/")]));

/// Creates a [File] for an entry in the [directory] directory.
File dirFile(Directory directory, String fileName) =>
    File(pathJoin(directory.path, fileName));

/// Creates a package: URI.
Uri pkg(String packageName, String packagePath) {
  var path =
      "$packageName${packagePath.startsWith('/') ? "" : "/"}$packagePath";
  return new Uri(scheme: "package", path: path);
}

// Remove if not used.
String configFromPackages(List<List<String>> packages) => """
{
  "configVersion": 2,
  "packages": [
${packages.map((nu) => """
    {
      "name": "${nu[0]}",
      "rootUri": "${nu[1]}"
    }""").join(",\n")}
  ]
}
""";

/// Mimics a directory structure of [description] and runs [fileTest].
///
/// Description is a map, each key is a file entry. If the value is a map,
/// it's a subdirectory, otherwise it's a file and the value is the content
/// as a string.
void loaderTest(String name, Map<String, Object> description,
    void loaderTest(Uri root, Future<Uint8List> loader(Uri uri))) {
  Uri root = Uri(scheme: "test", path: "/");
  Future<Uint8List> loader(Uri uri) async {
    var path = uri.path;
    if (!uri.isScheme("test") || !path.startsWith("/")) return null;
    var parts = path.split("/");
    dynamic value = description;
    for (int i = 1; i < parts.length; i++) {
      if (value is! Map<String, dynamic>) return null;
      value = value[parts[i]];
    }
    if (value is String) return utf8.encode(value);
    return null;
  }

  test(name, () => loaderTest(root, loader));
}
