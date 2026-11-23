// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Running [updateDocument] over a directory of markdown files.
library;

import 'dart:convert' show utf8;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'diagnostic.dart';
import 'update.dart';
import 'util/files.dart';

/// What [updateDirectory] did.
final class RunOutcome {
  /// Markdown files that were looked at.
  final int scanned;

  /// Documents that are out of date, with the number of stale blocks in each.
  final Map<String, int> stale;

  /// Errors encountered while checking or updating documents, in file order.
  final List<ExampleFormatException> diagnostics;

  /// Non-fatal warnings encountered while scanning or resolving documents.
  final List<ExampleWarning> warnings;

  RunOutcome({
    required this.scanned,
    required this.stale,
    required this.diagnostics,
    this.warnings = const [],
  });
}

/// Updates or checks every markdown file under [directory].
///
/// With [write], out-of-date documents are rewritten; without it they are
/// only reported, which is what `validate` does in CI.
///
/// Each document is resolved against **its own** package root (the nearest
/// enclosing directory containing `pubspec.yaml`), or [directory] itself for
/// relative references in documents outside any package.
RunOutcome updateDirectory({
  required String directory,
  required bool write,
}) {
  final root = p.normalize(p.absolute(directory));
  final diagnostics = <ExampleFormatException>[];
  final warnings = <ExampleWarning>[];
  final stale = <String, int>{};
  var scanned = 0;

  for (final file in markdownFiles(root)) {
    final label = p.relative(file, from: root);

    final String source;
    try {
      source = utf8.decode(File(file).readAsBytesSync());
    } on FormatException {
      warnings.add(ExampleWarning('skipping non-UTF-8 file `$label`'));
      continue;
    } on FileSystemException catch (e) {
      diagnostics.add(
        ExampleFormatException('cannot read `$label` (${e.message})'),
      );
      continue;
    }
    scanned++;

    if (!source.toLowerCase().contains('@example')) continue;

    final result = updateDocument(
      source: source,
      documentPath: file,
      packageRoot: packageRootOf(file),
      displayRoot: root,
      sourceUrl: p.toUri(label),
      readFile: (path) {
        final example = File(path);
        if (!example.existsSync()) return null;
        try {
          return utf8.decode(example.readAsBytesSync());
        } on FormatException {
          throw ExampleFormatException(
            '`${p.relative(path, from: root)}` is not valid UTF-8 text',
          );
        } on FileSystemException catch (e) {
          throw ExampleFormatException(
            'cannot read `${p.relative(path, from: root)}` (${e.message})',
          );
        }
      },
    );
    diagnostics.addAll(result.diagnostics);
    warnings.addAll(result.warnings);

    if (result.stale.isNotEmpty) stale[label] = result.stale.length;
    if (result.updated == null) continue;

    if (write) {
      File(file).writeAsStringSync(result.updated!);
    }
  }

  return RunOutcome(
    scanned: scanned,
    stale: stale,
    diagnostics: diagnostics,
    warnings: warnings,
  );
}
