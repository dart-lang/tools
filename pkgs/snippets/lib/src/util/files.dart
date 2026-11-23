// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Every `.md` file under [root] (skipping hidden directories and `build/`),
/// in a stable order.
List<String> markdownFiles(String root) {
  final files = <String>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (!name.startsWith('.') && name != 'build') walk(entity);
      } else if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        files.add(entity.path);
      }
    }
  }

  walk(Directory(root));
  return files..sort();
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
