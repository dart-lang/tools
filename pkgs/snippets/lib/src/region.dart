// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Cutting a named region out of a source file.
///
/// The markers are dartdoc's, so one file can serve `{@example}` directives
/// and this tool at the same time:
///
/// ```dart
/// void main() {
///   // #region greeting
///   print('hello');
///   // #endregion
/// }
/// ```
///
/// Extraction is **line based and language agnostic**. A marker is any line
/// containing `#region <name>`, `#endregion` or `#hide`, wherever it occurs —
/// in a comment, in a string literal, in a YAML file, in a shell script. We do
/// not parse the host language, and that is the point: the same three markers
/// work everywhere.
///
/// Where dartdoc continues with best-effort output after reporting an error,
/// this tool *rewrites your documentation*, so a malformed region file throws
/// [ExampleFormatException] and the blocks referencing it are left alone:
///
/// * an unterminated `#region` is an error,
/// * a stray `#endregion`, or one labelled with a name other than the
///   innermost open region, is an error.
library;

import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import 'diagnostic.dart';
import 'util/scanner.dart';

final _crlfOrCr = RegExp(r'\r\n|\r');

/// Start of a region; group 1 is its name.
///
/// Copied from dartdoc, including the case-insensitivity and the lack of
/// anchors.
final _regionStart = RegExp(r'#region[ \t]+(\S+)', caseSensitive: false);

/// End of the innermost open region; group 1 is an optional region label
/// (ignoring trailing comment closers such as `-->` or `*/`).
final _regionEnd = RegExp(
  r'#endregion\b(?:[ \t]+([\w.-]+)(?=\s|$))?',
  caseSensitive: false,
);

/// A line to drop from the output.
final _hide = RegExp(r'#hide\b', caseSensitive: false);

/// Returns [region] of [source], or the whole file if [region] is `null`.
///
/// Marker lines and `#hide` lines are removed from a named region, and left
/// untouched (without parsing markers) when the whole file is requested,
/// matching dartdoc. If [region] is opened more than once in [source], the
/// lines from each block are concatenated in order.
///
/// The result is empty, or ends with a single `\n`. Line endings are
/// normalised to `\n`: the document being written into decides what its own
/// lines end with, not the example file.
///
/// Throws [ExampleFormatException] when extracting a named [region] if the
/// markers in [source] are malformed, or if there is no such region.
String extractRegion(
  FileSpan source, {
  String? region,
}) {
  if (region == null) {
    if (source.length == 0) return '';
    final normalized = source.text.replaceAll(_crlfOrCr, '\n');
    return normalized.endsWith('\n') ? normalized : '$normalized\n';
  }

  final scanner = SpanScanner.within(source);
  final selected = <String>[];
  final open = <({String name, FileSpan span})>[];
  final seen = <String>{};

  while (!scanner.isDone) {
    final line = scanner.scanLine();
    final text = line.text;

    if (_regionStart.firstMatch(text) case final start?) {
      final name = start[1]!;
      open.add((name: name, span: line.trim()));
      seen.add(name);
    } else if (_regionEnd.firstMatch(text) case final end?) {
      if (open.isEmpty) {
        throw ExampleFormatException(
          '`#endregion` without a `#region`',
          line.trim(),
        );
      }
      final closed = end[1];
      final innermost = open.removeLast();
      if (closed != null && closed != innermost.name) {
        throw ExampleFormatException(
          '`#endregion` labelled `$closed` closes `${innermost.name}`, the '
          'innermost open region',
          line.trim(),
        );
      }
    } else if (_hide.hasMatch(text)) {
      continue;
    } else if (open.any((r) => r.name == region)) {
      selected.add(text);
    }
  }

  if (open.isNotEmpty) {
    final unclosed = open.last;
    throw ExampleFormatException(
      'region `${unclosed.name}` is never closed; add `#endregion`',
      unclosed.span,
    );
  }

  // No span: the mistake is in the reference, not at a place in this file.
  if (!seen.contains(region)) {
    throw ExampleFormatException(
      seen.isEmpty
          ? 'the referenced file has no region `$region`; it defines no '
              'regions at all'
          : 'the referenced file has no region `$region`; it defines '
              '${seen.map((r) => '`$r`').join(', ')}',
    );
  }

  if (selected.isEmpty) return '';
  return '${selected.join('\n')}\n';
}
