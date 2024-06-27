// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

/// Given [value], tries to format it into a plain string recognizable by YAML.
///
/// Not all values can be formatted into a plain string. If the string contains
/// an escape sequence, it can only be detected when in a double-quoted
/// sequence. Plain strings may also be misinterpreted by the YAML parser (e.g.
/// ' null').
///
/// Returns `null` if [value] cannot be encoded as a plain string.
String? _tryYamlEncodePlain(String value) {
  /// If it contains a dangerous character we want to wrap the result with
  /// double quotes because the double quoted style allows for arbitrary
  /// strings with "\" escape sequences.
  ///
  /// See 7.3.1 Double-Quoted Style
  /// https://yaml.org/spec/1.2/spec.html#id2787109
  return isDangerousString(value) ? null : value;
}

/// Checks if [string] has unprintable characters according to
/// [unprintableCharCodes].
bool _hasUnprintableCharacters(String string) {
  final codeUnits = string.codeUnits;

  for (final key in unprintableCharCodes.keys) {
    if (codeUnits.contains(key)) return true;
  }

  return false;
}

/// Generates a YAML-safe double-quoted string based on [string], escaping the
/// list of characters as defined by the YAML 1.2 spec.
///
/// See 5.7 Escaped Characters https://yaml.org/spec/1.2/spec.html#id2776092
String _yamlEncodeDoubleQuoted(String string) {
  final buffer = StringBuffer();
  for (final codeUnit in string.codeUnits) {
    if (doubleQuoteEscapeChars[codeUnit] != null) {
      buffer.write(doubleQuoteEscapeChars[codeUnit]);
    } else {
      buffer.writeCharCode(codeUnit);
    }
  }

  return '"$buffer"';
}

/// Encodes [string] as YAML single quoted string.
///
/// Returns `null`, if the [string] can't be encoded as single-quoted string.
/// This might happen if it contains line-breaks or [_hasUnprintableCharacters].
///
/// See: https://yaml.org/spec/1.2.2/#732-single-quoted-style
String? _tryYamlEncodeSingleQuoted(String string) {
  // If [string] contains a newline we'll use double quoted strings instead.
  // Single quoted strings can represent newlines, but then we have to use an
  // empty line (replace \n with \n\n). But since leading spaces following
  // line breaks are ignored, we can't represent "\n ".
  // Thus, if the string contains `\n` and we're asked to do single quoted,
  // we'll fallback to a double quoted string.
  if (_hasUnprintableCharacters(string) || string.contains('\n')) return null;

  final result = string.replaceAll('\'', '\'\'');
  return '\'$result\'';
}

/// Attempts to encode a [string] as a _YAML folded string_ and apply the
/// appropriate _chomping indicator_.
///
/// Returns `null`, if the [string] cannot be encoded as a _YAML folded
/// string_.
///
/// **Examples** of folded strings.
/// ```yaml
/// # With the "strip" chomping indicator
/// key: >-
///   my folded
///   string
///
/// # With the "keep" chomping indicator
/// key: >+
///   my folded
///   string
/// ```
///
/// See: https://yaml.org/spec/1.2.2/#813-folded-style
String? _tryYamlEncodeFolded(String string, int indentSize, String lineEnding) {
  // A string that starts with space or newline followed by space can't be
  // encoded in folded mode.
  if (string.isEmpty || string.trimLeft().length != string.length) return null;

  if (_hasUnprintableCharacters(string)) return null;

  // TODO: Are there other strings we can't encode in folded mode?

  final indent = ' ' * indentSize;

  /// Remove trailing `\n` & white-space to ease string folding
  var trimmed = string.trimRight();
  final stripped = string.substring(trimmed.length);

  final trimmedSplit =
      trimmed.replaceAll('\n', lineEnding + indent).split(lineEnding);

  /// Try folding to match specification:
  /// * https://yaml.org/spec/1.2.2/#65-line-folding
  trimmed = trimmedSplit.reduceIndexed((index, previous, current) {
    var updated = current;

    /// If initially empty, this line holds only `\n` or white-space. This
    /// tells us we don't need to apply an additional `\n`.
    ///
    /// See https://yaml.org/spec/1.2.2/#64-empty-lines
    ///
    /// If this line is not empty, we need to apply an additional `\n` if and
    /// only if:
    ///   1. The preceding line was non-empty too
    ///   2. If the current line doesn't begin with white-space
    ///
    /// Such that we apply `\n` for `foo\nbar` but not `foo\n bar`.
    if (current.trim().isNotEmpty &&
        trimmedSplit[index - 1].trim().isNotEmpty &&
        !current.replaceFirst(indent, '').startsWith(' ')) {
      updated = lineEnding + updated;
    }

    /// Apply a `\n` by default.
    return previous + lineEnding + updated;
  });

  return '>-\n'
      '$indent$trimmed'
      '${stripped.replaceAll('\n', lineEnding + indent)}';
}

/// Attempts to encode a [string] as a _YAML literal string_ and apply the
/// appropriate _chomping indicator_.
///
/// Returns `null`, if the [string] cannot be encoded as a _YAML literal
/// string_.
///
/// **Examples** of literal strings.
/// ```yaml
/// # With the "strip" chomping indicator
/// key: |-
///   my literal
///   string
///
/// # Without chomping indicator
/// key: |
///   my literal
///   string
/// ```
///
/// See: https://yaml.org/spec/1.2.2/#812-literal-style
String? _tryYamlEncodeLiteral(
    String string, int indentSize, String lineEnding) {
  if (string.isEmpty || string.trimLeft().length != string.length) return null;

  // A string that starts with space or newline followed by space can't be
  // encoded in literal mode.
  if (_hasUnprintableCharacters(string)) return null;

  // TODO: Are there other strings we can't encode in literal mode?

  final indent = ' ' * indentSize;

  /// Simplest block style.
  /// * https://yaml.org/spec/1.2.2/#812-literal-style
  return '|-\n$indent${string.replaceAll('\n', lineEnding + indent)}';
}

/// Encodes a flow [YamlScalar] based on the provided [YamlScalar.style].
///
/// Falls back to [ScalarStyle.DOUBLE_QUOTED] if the [yamlScalar] cannot be
/// encoded with the [YamlScalar.style] or with [ScalarStyle.PLAIN] when the
/// [yamlScalar] is not a [String].
String _yamlEncodeFlowScalar(YamlScalar yamlScalar) {
  final YamlScalar(:value, :style) = yamlScalar;

  if (value is! String) {
    return value.toString();
  }

  switch (style) {
    /// Only encode as double-quoted if it's a string.
    case ScalarStyle.DOUBLE_QUOTED:
      return _yamlEncodeDoubleQuoted(value);

    case ScalarStyle.SINGLE_QUOTED:
      return _tryYamlEncodeSingleQuoted(value) ??
          _yamlEncodeDoubleQuoted(value);

    /// Cast into [String] if [null] as this condition only returns [null]
    /// for a [String] that can't be encoded.
    default:
      return _tryYamlEncodePlain(value) ?? _yamlEncodeDoubleQuoted(value);
  }
}

/// Encodes a block [YamlScalar] based on the provided [YamlScalar.style].
///
/// Falls back to [ScalarStyle.DOUBLE_QUOTED] if the [yamlScalar] cannot be
/// encoded with the [YamlScalar.style] provided.
String _yamlEncodeBlockScalar(
  YamlScalar yamlScalar,
  int indentation,
  String lineEnding,
) {
  final YamlScalar(:value, :style) = yamlScalar;
  assertValidScalar(value);

  if (value is! String) {
    return value.toString();
  }

  switch (style) {
    /// Prefer 'plain', fallback to "double quoted"
    case ScalarStyle.PLAIN:
      return _tryYamlEncodePlain(value) ?? _yamlEncodeDoubleQuoted(value);

    // Prefer 'single quoted', fallback to "double quoted"
    case ScalarStyle.SINGLE_QUOTED:
      return _tryYamlEncodeSingleQuoted(value) ??
          _yamlEncodeDoubleQuoted(value);

    /// Prefer folded string, fallback to "double quoted"
    case ScalarStyle.FOLDED:
      return _tryYamlEncodeFolded(value, indentation, lineEnding) ??
          _yamlEncodeDoubleQuoted(value);

    /// Prefer literal string, fallback to "double quoted"
    case ScalarStyle.LITERAL:
      return _tryYamlEncodeLiteral(value, indentation, lineEnding) ??
          _yamlEncodeDoubleQuoted(value);

    /// Prefer plain, fallback to "double quoted"
    default:
      return _tryYamlEncodePlain(value) ?? _yamlEncodeDoubleQuoted(value);
  }
}

/// Returns [value] with the necessary formatting applied in a flow context.
///
/// If [value] is a [YamlNode], we try to respect its [YamlScalar.style]
/// parameter where possible. Certain cases make this impossible (e.g. a plain
/// string scalar that starts with '>', a child having a block style
/// parameters), in which case we will produce [value] with default styling
/// options.
String yamlEncodeFlow(YamlNode value) {
  if (value is YamlList) {
    final list = value.nodes;

    final safeValues = list.map(yamlEncodeFlow);
    return '[${safeValues.join(', ')}]';
  } else if (value is YamlMap) {
    final safeEntries = value.nodes.entries.map((entry) {
      final safeKey = yamlEncodeFlow(entry.key as YamlNode);
      final safeValue = yamlEncodeFlow(entry.value);
      return '$safeKey: $safeValue';
    });

    return '{${safeEntries.join(', ')}}';
  }

  return _yamlEncodeFlowScalar(value as YamlScalar);
}

/// Returns [value] with the necessary formatting applied in a block context.
String yamlEncodeBlock(
  YamlNode value,
  int indentation,
  String lineEnding,
) {
  const additionalIndentation = 2;

  if (!isBlockNode(value)) return yamlEncodeFlow(value);

  final newIndentation = indentation + additionalIndentation;

  if (value is YamlList) {
    if (value.isEmpty) return '${' ' * indentation}[]';

    Iterable<String> safeValues;

    final children = value.nodes;

    safeValues = children.map((child) {
      var valueString = yamlEncodeBlock(child, newIndentation, lineEnding);
      if (isCollection(child) && !isFlowYamlCollectionNode(child)) {
        valueString = valueString.substring(newIndentation);
      }

      return '${' ' * indentation}- $valueString';
    });

    return safeValues.join(lineEnding);
  } else if (value is YamlMap) {
    if (value.isEmpty) return '${' ' * indentation}{}';

    return value.nodes.entries.map((entry) {
      final MapEntry(:key, :value) = entry;

      final safeKey = yamlEncodeFlow(key as YamlNode);
      final formattedKey = ' ' * indentation + safeKey;

      final formattedValue = yamlEncodeBlock(
        value,
        newIndentation,
        lineEnding,
      );

      /// Empty collections are always encoded in flow-style, so new-line must
      /// be avoided
      if (isCollection(value) && !isEmpty(value)) {
        return '$formattedKey:$lineEnding$formattedValue';
      }

      return '$formattedKey: $formattedValue';
    }).join(lineEnding);
  }

  return _yamlEncodeBlockScalar(
    value as YamlScalar,
    newIndentation,
    lineEnding,
  );
}

/// List of unprintable characters.
///
/// See 5.7 Escape Characters https://yaml.org/spec/1.2/spec.html#id2776092
final Map<int, String> unprintableCharCodes = {
  0: '\\0', //  Escaped ASCII null (#x0) character.
  7: '\\a', //  Escaped ASCII bell (#x7) character.
  8: '\\b', //  Escaped ASCII backspace (#x8) character.
  11: '\\v', // 	Escaped ASCII vertical tab (#xB) character.
  12: '\\f', //  Escaped ASCII form feed (#xC) character.
  13: '\\r', //  Escaped ASCII carriage return (#xD) character. Line Break.
  27: '\\e', //  Escaped ASCII escape (#x1B) character.
  133: '\\N', //  Escaped Unicode next line (#x85) character.
  160: '\\_', //  Escaped Unicode non-breaking space (#xA0) character.
  8232: '\\L', //  Escaped Unicode line separator (#x2028) character.
  8233: '\\P', //  Escaped Unicode paragraph separator (#x2029) character.
};

/// List of escape characters.
///
/// See 5.7 Escape Characters https://yaml.org/spec/1.2/spec.html#id2776092
final Map<int, String> doubleQuoteEscapeChars = {
  ...unprintableCharCodes,
  9: '\\t', //  Escaped ASCII horizontal tab (#x9) character. Printable
  10: '\\n', //  Escaped ASCII line feed (#xA) character. Line Break.
  34: '\\"', //  Escaped ASCII double quote (#x22).
  47: '\\/', //  Escaped ASCII slash (#x2F), for JSON compatibility.
  92: '\\\\', //  Escaped ASCII back slash (#x5C).
};
