// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:package_config/src/util_io.dart';
import 'package:test/test.dart';

/// Creates a directory structure from [description] and runs [fileTest].
///
/// Description is a map, each key is a file entry. If the value is a map,
/// it's a subdirectory, otherwise it's a file and the value is the content
/// as a string.
/// Introduces a group to hold the [setUp]/[tearDown] logic.
void fileTest(
  String name,
  Map<String, Object> description,
  void Function(Directory directory) fileTest,
) {
  group('file-test', () {
    var tempDir = Directory.systemTemp.createTempSync('pkgcfgtest');
    setUp(() {
      _createFiles(tempDir, description);
    });
    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    test(name, () => fileTest(tempDir));
  });
}

// Creates temporary files in the target directory.
void _createFiles(Directory target, Map<Object?, Object?> description) {
  description.forEach((name, content) {
    var entryName = pathJoin(target.path, '$name');
    if (content is Map<Object?, Object?>) {
      _createFiles(Directory(entryName)..createSync(), content);
    } else {
      File(entryName).writeAsStringSync(content as String, flush: true);
    }
  });
}

/// Creates a [Directory] for a subdirectory of [parent].
Directory subdir(Directory parent, String dirName) =>
    Directory(_concat(parent, dirName));

/// Creates a [File] for an entry in the [directory] directory.
File dirFile(Directory directory, String fileName) =>
    File(_concat(directory, fileName));

/// Splits [subPath] on `/`s and appends to [directory].
String _concat(Directory directory, String subPath) =>
    pathAppend(directory, subPath.split('/'));
