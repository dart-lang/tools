// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Bringing one markdown document up to date with the files it references.
library;

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'diagnostic.dart';
import 'indent.dart';
import 'markdown/locator.dart';
import 'markdown/references.dart';
import 'markdown/splice.dart';
import 'region.dart';
import 'resolve.dart';

/// Reads the file at [path], or returns `null` if there is no such file.
///
/// An argument rather than `dart:io` so that the driver can be tested against
/// a `Map<String, String>`, which is both faster and far easier to read than
/// a temporary directory.
typedef FileReader = String? Function(String path);

/// What [updateDocument] made of a document.
final class UpdateResult {
  /// The updated document, or `null` if nothing needed to change.
  ///
  /// `update` writes this; `validate` only reports that it exists.
  final String? updated;

  /// References whose blocks were out of date, whether or not they could be
  /// updated.
  final List<ExampleReference> stale;

  /// Errors encountered while checking or updating this document.
  final List<ExampleFormatException> diagnostics;

  /// Non-fatal warnings encountered while checking or updating this document.
  final List<ExampleWarning> warnings;

  UpdateResult({
    required this.updated,
    required this.stale,
    required this.diagnostics,
    this.warnings = const [],
  });
}

/// Returns [source] with every referenced code block filled in.
///
/// [documentPath] and [packageRoot] (when non-null) are absolute. When
/// [packageRoot] is `null`, leading-`/` references report an error and relative
/// references resolve within [displayRoot] (if provided). Diagnostics in the
/// document are labelled with [sourceUrl], which defaults to [documentPath].
UpdateResult updateDocument({
  required String source,
  required String documentPath,
  required String? packageRoot,
  required FileReader readFile,
  String? displayRoot,
  Uri? sourceUrl,
}) {
  final diagnostics = <ExampleFormatException>[];
  final warnings = <ExampleWarning>[];
  final stale = <ExampleReference>[];

  if (!source.toLowerCase().contains('@example')) {
    return UpdateResult(updated: null, stale: stale, diagnostics: diagnostics);
  }

  final document = SourceFile.fromString(
    source,
    url: sourceUrl ?? p.toUri(documentPath),
  ).span(0);
  final blocks = locateFencedCodeBlocks(document);

  final references = findReferences(blocks, report: diagnostics.add);
  if (references.isEmpty) {
    return UpdateResult(updated: null, stale: stale, diagnostics: diagnostics);
  }

  final boundaryRoot = packageRoot ?? displayRoot;

  // Work out what every block should contain before changing anything. A
  // broken reference is reported and skipped; the other blocks are updated.
  final wanted = <ExampleReference, String>{};
  for (final reference in references) {
    if (packageRoot == null && reference.path.startsWith('/')) {
      diagnostics.add(ExampleFormatException(
        'leading `/` requires a `pubspec.yaml` in a parent directory of this '
        'file',
        reference.span,
      ));
      continue;
    }
    if (boundaryRoot == null) {
      diagnostics.add(ExampleFormatException(
        'no `pubspec.yaml` found in any parent directory of this file',
        reference.span,
      ));
      continue;
    }
    if (reference.block.closeFence == null) {
      diagnostics.add(ExampleFormatException(
        'this code block has no closing fence, so it cannot be updated safely',
        reference.block.openFence,
      ));
      continue;
    }

    final String content;
    try {
      content = _contentFor(
        reference,
        documentPath: documentPath,
        packageRoot: boundaryRoot,
        displayRoot: displayRoot ?? boundaryRoot,
        readFile: readFile,
        onWarning: (msg) => warnings.add(ExampleWarning(msg, reference.span)),
      );
    } on ExampleFormatException catch (e) {
      diagnostics.add(
        e.span != null ? e : ExampleFormatException(e.message, reference.span),
      );
      continue;
    }

    if (content == reference.block.content) continue;
    stale.add(reference);
    wanted[reference] = content;
  }
  if (wanted.isEmpty) {
    return UpdateResult(
      updated: null,
      stale: stale,
      diagnostics: diagnostics,
      warnings: warnings,
    );
  }

  // Splice from the end so that the offsets of the blocks still to be done
  // are not disturbed.
  var updated = source;
  for (final reference in wanted.keys
      .sortedBy<SourceSpan>((r) => r.block.contentSpan)
      .reversed) {
    updated = spliceContent(updated, reference.block, wanted[reference]!);
  }

  return UpdateResult(
    updated: updated,
    stale: stale,
    diagnostics: diagnostics,
    warnings: warnings,
  );
}

/// The content [reference] asks for.
String _contentFor(
  ExampleReference reference, {
  required String documentPath,
  required String packageRoot,
  required String displayRoot,
  required FileReader readFile,
  required void Function(String message) onWarning,
}) {
  final path = resolveReference(
    packageRoot: packageRoot,
    documentPath: documentPath,
    reference: reference.path,
    onWarning: onWarning,
  );
  final source = readFile(path);
  if (source == null) {
    throw ExampleFormatException(
      'there is no file `${reference.path}` '
      '(looked for `${p.relative(path, from: displayRoot)}`)',
      reference.span,
    );
  }
  for (final MapEntry(:key, :value) in reference.options.entries) {
    if (key != 'indent') {
      throw ExampleFormatException(
        'unknown option `$key=$value`; '
        'expected `indent=strip` or `indent=keep`',
        reference.span,
      );
    }
  }
  final indent = switch (reference.options['indent']) {
    null || 'strip' => true,
    'keep' => false,
    final other => throw ExampleFormatException(
        'invalid `indent=$other`; expected `indent=strip` or `indent=keep`',
        reference.span,
      ),
  };
  final relativePath = p.relative(path, from: displayRoot);
  final example = SourceFile.fromString(
    source,
    url: p.toUri(relativePath),
  ).span(0);
  final content = extractRegion(example, region: reference.region);
  return indent ? stripIndentation(content) : content;
}
