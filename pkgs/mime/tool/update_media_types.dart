// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;

/// Define additions to the base apache/httpd mime set.
///
/// These are deltas to the base set that make sense in a Dart context
/// (programming environments, Dart implemented web servers, ...).
const Map<String, List<String>> mimeAdditions = {
  'text/markdown': ['md', 'markdown'],
  'text/x-dart': ['dart'],
};

void main() async {
  // https://github.com/apache/httpd/blob/trunk/docs/conf/mime.types
  const mimeTypesUrl =
      'https://raw.githubusercontent.com/apache/httpd/refs/heads/trunk/docs/conf/mime.types';

  print('Reading from $mimeTypesUrl ...');
  final response = await http.get(Uri.parse(mimeTypesUrl));

  final lines = response.body
      .split('\n')
      .where((line) => !line.startsWith('#'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  final extensionToMime = <String, String>{};
  final mimeToExtensions = <String, List<String>>{};

  final wsRegex = RegExp('  +');
  for (var line in lines) {
    line = line.replaceAll('\t', ' ').replaceAll(wsRegex, ' ');

    final segments = line.split(' ');

    final mime = segments[0];
    final extensions = segments.sublist(1);

    mimeToExtensions[mime] = extensions;
    for (final ext in extensions) {
      extensionToMime[ext] = mime;
    }
  }

  print('read ${mimeToExtensions.length} mime types.');

  // Augment the table with additional types.

  for (final entry in mimeAdditions.entries) {
    final mime = entry.key;
    final extensions = entry.value;

    mimeToExtensions[mime] = extensions;
    for (final ext in extensions) {
      extensionToMime[ext] = mime;
    }
  }

  print('');

  // write mimeToExtensions
  final buf = StringBuffer();
  buf.writeln('const Map<String, List<String>> mimeToExtensions = {');
  final sortedMimeTypes = mimeToExtensions.keys.toList()..sort();
  for (final mime in sortedMimeTypes) {
    final exts = mimeToExtensions[mime]!;
    final describe = exts.map((ext) => "'$ext'").join(', ');
    buf.writeln("  '$mime': [$describe],");
  }
  buf.writeln('};');

  buf.writeln();

  // write extensionToMime
  buf.writeln('const Map<String, String> extensionToMime = {');
  final sortedExtensions = extensionToMime.keys.toList()..sort();
  for (final ext in sortedExtensions) {
    final mime = extensionToMime[ext];
    buf.writeln("  '$ext': '$mime',");
  }
  buf.writeln('};');

  // Write Dart file.
  final out = writeDartFile('mime_tables.g.dart', buf.toString());
  print('wrote ${out.path}.');
}

File writeDartFile(String name, String content) {
  final file = File.fromUri(Platform.script.resolve('../lib/src/$name'));

  file.writeAsStringSync('''
// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Generated file - do not edit.

$content
''');

  // Format the generated file.
  Process.runSync(Platform.resolvedExecutable, ['format', file.path]);

  return file;
}
