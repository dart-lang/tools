// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

/// Every `.md` file under [root] (skipping hidden directories and `build/`),
/// in a stable order.
List<String> markdownFiles(String root) => Directory(root)
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .map((file) => file.path)
    .where((path) =>
        path.toLowerCase().endsWith('.md') &&
        !_inIgnoredDirectory(p.relative(path, from: root)))
    .sorted();

bool _inIgnoredDirectory(String relativePath) {
  final parts = p.split(relativePath);
  return parts
      .take(parts.length - 1)
      .any((dir) => dir.startsWith('.') || dir == 'build');
}

/// The nearest enclosing directory of [path] containing a `pubspec.yaml`, or
/// `null` if none exists.
String? packageRootOf(String path) {
  var dir = Directory(p.normalize(p.absolute(p.dirname(path))));
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
