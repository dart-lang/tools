// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mime/mime.dart';
import 'package:mime/src/default_extension_map.dart';

void main(List<String> args) {
  // Get all the mime types.
  final mimeTypes = defaultExtensionMap.values.toSet().toList()..sort();

  // Find all their extensions.
  final mimeToExts = <String, List<String>>{};

  for (final entry in defaultExtensionMap.entries) {
    final ext = entry.key;
    final mime = entry.value;

    mimeToExts.putIfAbsent(mime, () => []).add(ext);
  }

  // Emit the table.
  const marker = '<!-- table -->\n';
  final file = File('doc/mime_types.md');
  var contents = file.readAsStringSync();
  final prefix =
      contents.substring(0, contents.indexOf(marker) + marker.length);
  final suffix = contents.substring(contents.lastIndexOf(marker));

  final buf = StringBuffer();
  buf.write('''
| MIME type | Default ext | Additional exts |
| - | - | - |
''');

  for (final mime in mimeTypes) {
    final defaultExt = extensionFromMime(mime)!;
    final exts = mimeToExts[mime]!;

    exts.remove(defaultExt);
    exts.sort();

    final decribeMime = '`$mime`';
    final decribeExt = '`$defaultExt`';
    final describeExts = exts.map((ext) => '`$ext`').join(', ');

    buf.writeln('| $decribeMime | $decribeExt | $describeExts |');
  }

  contents = '$prefix\n$buf\n$suffix';
  file.writeAsStringSync(contents);
}

String min(String str, [int width = 12]) => str.padRight(width);
