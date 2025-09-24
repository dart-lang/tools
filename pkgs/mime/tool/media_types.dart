// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Script to update the `../doc/media_types.md` file from
/// [defaultExtensionMap].
library;

import 'dart:io';

import 'package:mime/mime.dart';
import 'package:mime/src/default_extension_map.dart' show defaultExtensionMap;

void main() {
  // Find all the mime types and extensions.
  final mimeToExts = <String, List<String>>{};

  for (final entry in defaultExtensionMap.entries) {
    final ext = entry.key;
    final mime = entry.value;

    (mimeToExts[mime] ??= []).add(ext);
  }

  final mimeTypes = [...mimeToExts.keys]..sort();

  // Emit the table.
  const startMarker = '<!-- start table -->\n';
  const endMarker = '<!-- end table -->\n';

  final file = File.fromUri(Platform.script.resolve('../doc/media_types.md'));
  final contents = file.readAsStringSync();
  final prefix =
      contents.substring(0, contents.indexOf(startMarker) + startMarker.length);
  final suffix = contents.substring(contents.lastIndexOf(endMarker));

  final buf = StringBuffer(prefix);
  buf.writeln();
  buf.write('''
| MIME type                                | Default     | Additional          |
| ---------------------------------------- | ----------- | ------------------- |
''');

  for (final mime in mimeTypes) {
    final defaultExt = extensionFromMime(mime)!;
    final exts = mimeToExts[mime]!.toList();

    exts.remove(defaultExt);
    exts.sort();

    final additional = exts.join(', ');

    buf.writeln('| ${markdownEscape(mime).padRight(40)} | '
        '${markdownEscape(defaultExt).padRight(11)} | '
        '${markdownEscape(additional).padRight(19)} |');
  }

  buf.writeln();
  buf.write(suffix);

  file.writeAsStringSync('${buf.toString().trim()}\n');
}

String markdownEscape(String markdown) {
  // See https://www.markdownguide.org/basic-syntax/#escaping-characters.

  // Escape the escape character.
  markdown = markdown.replaceAll(r'\', r'\\');

  // Escape other special characters.
  markdown = markdown.replaceAll('_', r'\_');

  return markdown;
}
