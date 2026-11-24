// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Computes [SourceEdit]s for mutating a [CstDocument].
///
/// Mutations operate directly on CST node and entry slot boundaries (such as
/// key, colon, and value offsets in mappings, or dash, comma, and delimiter
/// offsets in collections) while preserving surrounding comments and layout.
library;

import 'dart:math' show min;

import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';

import 'cst.dart';
import 'cst_helpers.dart';
import 'equality.dart';
import 'errors.dart';
import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';
import 'wrap.dart';

export 'cst_helpers.dart';

part 'cst_insert.dart';
part 'cst_remove.dart';
part 'cst_update.dart';

typedef _MutationEdit = ({
  SourceEdit edit,
  int? trailingBlockScalarBodyIndent,
});

// ---------------------------------------------------------------------------
// Encoding new content
// ---------------------------------------------------------------------------

/// A newly encoded value, together with how it must be joined to the syntax
/// that introduces it.
final class EncodedValue {
  /// The value's source text.
  ///
  /// When [ownLine] is true this begins with the value's own indentation.
  final String text;

  /// Whether the value must begin on a line of its own.
  ///
  /// Block collections must; everything else — scalars, including block
  /// scalars whose header stays on the introducing line, and flow collections —
  /// may follow the `-` or `:` directly.
  final bool ownLine;

  /// Body indentation of a trailing literal or folded block scalar if [text]
  /// ends with one, or `null` otherwise.
  final int? trailingBlockScalarBodyIndent;

  EncodedValue({
    required this.text,
    required this.ownLine,
    this.trailingBlockScalarBodyIndent,
  });
}

/// Whether [value] will be written as a block collection occupying its own
/// lines.
///
/// Empty collections are the exception: there is no way to write an empty block
/// collection, so they come out as `[]` or `{}` and stay on one line.
bool _spansOwnLines(YamlNode value) {
  if (!isBlockNode(value)) return false;
  return switch (value) {
    YamlList() => value.isNotEmpty,
    YamlMap() => value.isNotEmpty,
    _ => false,
  };
}

/// Encodes [value] for a slot introduced by an indicator (`:` or `-`) at
/// [indicatorColumn].
EncodedValue encodeValue(
  YamlNode value,
  LayoutStyle style, {
  required int indicatorColumn,
}) {
  if (_spansOwnLines(value)) {
    final encoded = yamlEncodeBlockWithInfo(
      value,
      indicatorColumn + style.indentStep,
      style.lineEnding,
    );
    return EncodedValue(
      text: encoded.text,
      ownLine: true,
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }
  // `yamlEncodeBlockWithInfo` indents the *body* of a block scalar two columns
  // past the indentation it is given, so pass [indicatorColumn] rather than
  // `indicatorColumn + style.indentStep`.
  final encoded = yamlEncodeBlockWithInfo(
    value,
    indicatorColumn,
    style.lineEnding,
  );
  return EncodedValue(
    text: encoded.text,
    ownLine: false,
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}

/// Encodes [value] to follow `- ` where the `-` stands at [dashColumn].
///
/// Block collections are written compactly on the same line as the `-` (as
/// `- a: 1` or `- - 1`), so their indentation is `dashColumn + 2` with the
/// first line's leading spaces dropped.
EncodedValue encodeAfterDash(
  YamlNode value,
  LayoutStyle style, {
  required int dashColumn,
}) {
  final compactColumn = dashColumn + 2;
  final encoded = yamlEncodeBlockWithInfo(
    value,
    compactColumn,
    style.lineEnding,
  );
  if (_spansOwnLines(value)) {
    // The encoder indents every line including the first; drop the first line's
    // indentation so the collection can start on the dash's line.
    return EncodedValue(
      text: encoded.text.substring(compactColumn),
      ownLine: false,
      trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
    );
  }
  return EncodedValue(
    text: encoded.text,
    ownLine: false,
    trailingBlockScalarBodyIndent: encoded.trailingBlockScalarBodyIndent,
  );
}
