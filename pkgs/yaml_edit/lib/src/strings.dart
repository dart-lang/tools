// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';

import 'utils.dart';

/// Given [value], tries to format it into a plain string recognizable by YAML.
/// If it fails, it defaults to returning a double-quoted string.
///
/// Not all values can be formatted into a plain string. If the string contains
/// an escape sequence, it can only be detected when in a double-quoted
/// sequence. Plain strings may also be misinterpreted by the YAML parser (e.g.
/// ' null').
String _tryYamlEncodePlain(Object? value) {
  if (value is YamlNode) {
    AssertionError(
        'YamlNodes should not be passed directly into getSafeString!');
  }

  assertValidScalar(value);

  if (value is String) {
    /// If it contains a dangerous character we want to wrap the result with
    /// double quotes because the double quoted style allows for arbitrary
    /// strings with "\" escape sequences.
    ///
    /// See 7.3.1 Double-Quoted Style
    /// https://yaml.org/spec/1.2/spec.html#id2787109
    if (isDangerousString(value)) {
      return _yamlEncodeDoubleQuoted(value);
    }

    return value;
  }

  return value.toString();
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

/// Generates a YAML-safe single-quoted string. Automatically escapes
/// single-quotes.
///
/// It is important that we ensure that [string] is free of unprintable
/// characters by calling [_hasUnprintableCharacters] before invoking this
/// function.
String _tryYamlEncodeSingleQuoted(String string) {
  // If [string] contains a newline we'll use double quoted strings instead.
  // Single quoted strings can represent newlines, but then we have to use an
  // empty line (replace \n with \n\n). But since leading spaces following
  // line breaks are ignored, we can't represent "\n ".
  // Thus, if the string contains `\n` and we're asked to do single quoted,
  // we'll fallback to a double quoted string.
  // TODO: Consider if we should make '\n' an unprintedable, this might make
  //       folded strings into double quoted -- some work is needed here.
  if (string.contains('\n')) {
    return _yamlEncodeDoubleQuoted(string);
  }
  final result = string.replaceAll('\'', '\'\'');
  return '\'$result\'';
}

/// Generates a YAML-safe folded string.
///
/// It is important that we ensure that [string] is free of unprintable
/// characters by calling [_hasUnprintableCharacters] before invoking this
/// function.
String _tryYamlEncodeFolded(String string, int indentation, String lineEnding) {
  String result;

  final trimmedString = string.trimRight();
  final removedPortion = string.substring(trimmedString.length);

  if (removedPortion.contains('\n')) {
    result = '>+\n${' ' * indentation}';
  } else {
    result = '>-\n${' ' * indentation}';
  }

  /// Duplicating the newline for folded strings preserves it in YAML.
  /// Assumes the user did not try to account for windows documents by using
  /// `\r\n` already
  return result +
      trimmedString.replaceAll('\n', lineEnding * 2 + ' ' * indentation) +
      removedPortion;
}

/// Generates a YAML-safe literal string.
///
/// It is important that we ensure that [string] is free of unprintable
/// characters by calling [_hasUnprintableCharacters] before invoking this
/// function.
String _tryYamlEncodeLiteral(
    String string, int indentation, String lineEnding) {
  final result = '|-\n$string';

  /// Assumes the user did not try to account for windows documents by using
  /// `\r\n` already
  return result.replaceAll('\n', lineEnding + ' ' * indentation);
}

/// Returns [value] with the necessary formatting applied in a flow context
/// if possible.
///
/// If [value] is a [YamlScalar], we try to respect its [YamlScalar.style]
/// parameter where possible. Certain cases make this impossible (e.g. a plain
/// string scalar that starts with '>'), in which case we will produce [value]
/// with default styling options.
String _yamlEncodeFlowScalar(YamlNode value) {
  if (value is YamlScalar) {
    assertValidScalar(value.value);

    final val = value.value;
    if (val is String) {
      if (_hasUnprintableCharacters(val) ||
          value.style == ScalarStyle.DOUBLE_QUOTED) {
        return _yamlEncodeDoubleQuoted(val);
      }

      if (value.style == ScalarStyle.SINGLE_QUOTED) {
        return _tryYamlEncodeSingleQuoted(val);
      }
    }

    return _tryYamlEncodePlain(value.value);
  }

  assertValidScalar(value);
  return _tryYamlEncodePlain(value);
}

/// Returns [value] with the necessary formatting applied in a block context
/// if possible.
///
/// If [value] is a [YamlScalar], we try to respect its [YamlScalar.style]
/// parameter where possible. Certain cases make this impossible (e.g. a folded
/// string scalar 'null'), in which case we will produce [value] with default
/// styling options.
String yamlEncodeBlockScalar(
  YamlNode value,
  int indentation,
  String lineEnding,
) {
  if (value is YamlScalar) {
    assertValidScalar(value.value);

    final val = value.value;
    if (val is String) {
      if (_hasUnprintableCharacters(val)) {
        return _yamlEncodeDoubleQuoted(val);
      }

      if (value.style == ScalarStyle.SINGLE_QUOTED) {
        return _tryYamlEncodeSingleQuoted(val);
      }

      // Strings with only white spaces will cause a misparsing
      if (val.trim().length == val.length && val.isNotEmpty) {
        if (value.style == ScalarStyle.FOLDED) {
          return _tryYamlEncodeFolded(val, indentation, lineEnding);
        }

        if (value.style == ScalarStyle.LITERAL) {
          return _tryYamlEncodeLiteral(val, indentation, lineEnding);
        }
      }
    }

    return _tryYamlEncodePlain(value.value);
  }

  assertValidScalar(value);

  /// The remainder of the possibilities are similar to how [getFlowScalar]
  /// treats [value].
  return _yamlEncodeFlowScalar(value);
}

/// Returns [value] with the necessary formatting applied in a flow context.
///
/// If [value] is a [YamlNode], we try to respect its [YamlScalar.style]
/// parameter where possible. Certain cases make this impossible (e.g. a plain
/// string scalar that starts with '>', a child having a block style
/// parameters), in which case we will produce [value] with default styling
/// options.
String yamlEncodeFlowString(YamlNode value) {
  if (value is YamlList) {
    final list = value.nodes;

    final safeValues = list.map(yamlEncodeFlowString);
    return '[${safeValues.join(', ')}]';
  } else if (value is YamlMap) {
    final safeEntries = value.nodes.entries.map((entry) {
      final safeKey = yamlEncodeFlowString(entry.key as YamlNode);
      final safeValue = yamlEncodeFlowString(entry.value);
      return '$safeKey: $safeValue';
    });

    return '{${safeEntries.join(', ')}}';
  }

  return _yamlEncodeFlowScalar(value);
}

/// Returns [value] with the necessary formatting applied in a block context.
String yamlEncodeBlockString(
  YamlNode value,
  int indentation,
  String lineEnding,
) {
  const additionalIndentation = 2;

  if (!isBlockNode(value)) return yamlEncodeFlowString(value);

  final newIndentation = indentation + additionalIndentation;

  if (value is YamlList) {
    if (value.isEmpty) return '${' ' * indentation}[]';

    Iterable<String> safeValues;

    final children = value.nodes;

    safeValues = children.map((child) {
      var valueString =
          yamlEncodeBlockString(child, newIndentation, lineEnding);
      if (isCollection(child) && !isFlowYamlCollectionNode(child)) {
        valueString = valueString.substring(newIndentation);
      }

      return '${' ' * indentation}- $valueString';
    });

    return safeValues.join(lineEnding);
  } else if (value is YamlMap) {
    if (value.isEmpty) return '${' ' * indentation}{}';

    return value.nodes.entries.map((entry) {
      final safeKey = yamlEncodeFlowString(entry.key as YamlNode);
      final formattedKey = ' ' * indentation + safeKey;
      final formattedValue =
          yamlEncodeBlockString(entry.value, newIndentation, lineEnding);

      /// Empty collections are always encoded in flow-style, so new-line must
      /// be avoided
      if (isCollection(entry.value) && !isEmpty(entry.value)) {
        return '$formattedKey:$lineEnding$formattedValue';
      }

      return '$formattedKey: $formattedValue';
    }).join(lineEnding);
  }

  return yamlEncodeBlockScalar(value, newIndentation, lineEnding);
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
