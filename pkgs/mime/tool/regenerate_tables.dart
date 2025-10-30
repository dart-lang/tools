// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

/// Additions to the base apache/httpd mime set.
const Map<String, List<String>> mimeAdditions = {
  'application/dicom': ['dcm'],
  'application/manifest+json': ['webmanifest'],
  'application/toml': ['toml'],
  'image/heic': ['heic'],
  'image/heif': ['heif'],
  'model/gltf-binary': ['glb'],
  'model/gltf+json': ['gltf'],
  'text/markdown': ['md', 'markdown'],
  'text/x-dart': ['dart'],
};

/// Preferred extensions for mime types.
const Map<String, String> preferredExtensions = {
  // For continuity with package:mime 2.0.0.
  'application/mathematica': 'nb',
  'application/mp21': 'mp21',

  // Best practices for preferred file extensions.
  'application/postscript': 'ps',
  'application/smil+xml': 'smil',
  'audio/mpeg': 'mp3',
  'audio/ogg': 'ogg',
  'image/jpeg': 'jpg',
  'model/vrml': 'vrml',
  'text/x-asm': 'asm',
  'text/x-pascal': 'pas',
  'video/mpeg': 'mpg',
  'video/quicktime': 'mov',
};

/// Mime type renames.
///
/// Generally these are places where the mime.types table differs from
/// https://www.iana.org/assignments/media-types/media-types.xhtml.
const Map<String, String> mimeConversions = {
  'audio/x-aac': 'audio/aac',
};

void main(List<String> args) {
  final mimeTypes = readMimeTypes();

  // Make any necessary mime name conversions.
  for (final oldMime in mimeConversions.keys) {
    final newMime = mimeConversions[oldMime]!;
    mimeTypes[newMime] = mimeTypes.remove(oldMime)!;
  }

  // Make sure we don't have conflicts with our preferred extension mappings.
  final customExtensions = preferredExtensions.values.toSet();
  for (final exts in mimeAdditions.values) {
    customExtensions.addAll(exts);
  }
  for (final entry in mimeTypes.entries.toList()) {
    final exts = entry.value;
    exts.removeWhere(customExtensions.contains);
    if (exts.isEmpty) {
      mimeTypes.remove(entry.key);
    }
  }

  // Add additonal mime types.
  for (final entry in mimeAdditions.entries) {
    final mime = entry.key;
    final exts = entry.value;

    mimeTypes.putIfAbsent(mime, () => []).addAll(exts);
  }

  // Use our preferred extensions for specific types.
  for (final entry in preferredExtensions.entries) {
    final mime = entry.key;
    final preferredExtension = entry.value;

    final exts = mimeTypes[mime]!;
    exts.remove(preferredExtension);
    exts.insert(0, preferredExtension);
  }

  // Sort to normalize the table, but preserve the position of the first file
  // extension.
  final sortedMimeTypes = <String, List<String>>{};
  for (final mime in mimeTypes.keys.toList()..sort()) {
    final exts = mimeTypes[mime]!;
    final defaultExt = exts.first;
    final other = exts.sublist(1)..sort();
    sortedMimeTypes[mime] = [defaultExt, ...other];
  }

  var file = writeMediaTypesFile(sortedMimeTypes);
  print('Wrote ${path.relative(file.path)}.');

  file = updateMediaTypesMarkdown(sortedMimeTypes);
  print('Updated ${path.relative(file.path)}.');
}

Map<String, List<String>> readMimeTypes() {
  final dataFile = File(path.join('third_party', 'httpd', 'mime.types'));

  print('Reading ${path.relative(dataFile.path)}...');

  final mimeToExtensions = <String, List<String>>{};
  final wsRegex = RegExp(' +');

  for (var line in dataFile
      .readAsLinesSync()
      .where((line) => !line.startsWith('#') && line.isNotEmpty)) {
    line = line.replaceAll('\t', ' ').replaceAll(wsRegex, ' ');
    final segments = line.split(' ');
    final mime = segments[0];
    final extensions = segments.sublist(1);

    mimeToExtensions[mime] = extensions;
  }

  return mimeToExtensions;
}

File writeMediaTypesFile(Map<String, List<String>> mimeToExtensions) {
  final out = StringBuffer();

  // Write the media to file extensions mapping table.
  out.writeln('''
/// A map of mime types to file extensions for that type.
/// 
/// If a mime type has multiple file extenions, the first in the list will be
/// returned as the preferred file extension for that type.''');
  out.writeln('const Map<String, List<String>> mediaToExtensions = {');
  for (final mime in mimeToExtensions.keys) {
    final exts = mimeToExtensions[mime]!;
    final describe = exts.map((ext) => "'$ext'").join(', ');
    out.writeln("  '$mime': [$describe],");
  }
  out.writeln('};');

  out.writeln();

  // Write the file extension to media type mapping table.
  out.writeln('/// A map of file extensions to their associated mime type.');
  out.writeln('const Map<String, String> extensionToMedia = {');
  final alreadySeen = <String, String>{};
  for (final mime in mimeToExtensions.keys) {
    final exts = mimeToExtensions[mime]!;
    for (final ext in exts) {
      if (alreadySeen.containsKey(ext)) {
        print(
            '- $ext already seen for ${alreadySeen[ext]}, not using for $mime');
      } else {
        out.writeln("  '$ext': '$mime',");
        alreadySeen[ext] = mime;
      }
    }
  }
  out.writeln('};');

  final outPath = path.join('lib/src/media_types.g.dart');
  return _writeDartFile(outPath, out.toString());
}

File updateMediaTypesMarkdown(Map<String, List<String>> mimeToExtensions) {
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

  for (final mime in mimeToExtensions.keys) {
    final exts = mimeToExtensions[mime]!.toList();

    final defaultExt = exts.first;
    exts.remove(defaultExt);

    final additional = exts.join(', ');

    buf.writeln('| ${mime.padRight(40)} | '
        '${defaultExt.padRight(11)} | '
        '${additional.padRight(19)} |');
  }

  buf.writeln();
  buf.write(suffix);

  file.writeAsStringSync('${buf.toString().trim()}\n');

  return file;
}

File _writeDartFile(String filePath, String content) {
  final file = File(filePath);
  file.writeAsStringSync('''
// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Generated file - do not edit.

$content
''');

  // Format the generated file.
  Process.runSync(Platform.resolvedExecutable, ['format', filePath]);

  return file;
}
