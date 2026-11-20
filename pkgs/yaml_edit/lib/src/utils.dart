// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'wrap.dart';

/// Invoke [fn] while setting [yamlWarningCallback] to [warn], and restore
/// [YamlWarningCallback] after [fn] returns.
///
/// Defaults to a [warn] function that ignores all warnings.
T withYamlWarningCallback<T>(
  T Function() fn, {
  YamlWarningCallback warn = _ignoreWarning,
}) {
  final original = yamlWarningCallback;
  try {
    yamlWarningCallback = warn;
    return fn();
  } finally {
    yamlWarningCallback = original;
  }
}

void _ignoreWarning(String warning, [SourceSpan? span]) {/* ignore warning */}

/// Determines if [string] is dangerous by checking if parsing the plain string
/// can return a result different from [string].
///
/// This function is also capable of detecting if non-printable characters are
/// in [string].
bool isDangerousString(String string) {
  try {
    final node = withYamlWarningCallback(() => loadYamlNode(string));
    if (node.value != string) {
      return true;
    }

    // [string] should also not contain the `[`, `]`, `,`, `{` and `}` indicator
    // characters.
    return string.contains(RegExp(r'\{|\[|\]|\}|,'));
  } catch (e) {
    /// This catch statement catches [ArgumentError] in `loadYamlNode` when
    /// a string can be interpreted as a URI tag, but catches for other
    /// [YamlException]s
    return true;
  }
}

/// Asserts that [value] is a valid scalar according to YAML.
///
/// A valid scalar is a number, String, boolean, or null.
void assertValidScalar(Object? value) {
  if (value is num || value is String || value is bool || value == null) {
    return;
  }

  throw ArgumentError.value(value, 'value', 'Not a valid scalar type!');
}

/// Checks if [node] is a [YamlNode] with block styling.
///
/// [ScalarStyle.ANY] and [CollectionStyle.ANY] are considered to be block
/// styling by default for maximum flexibility.
bool isBlockNode(YamlNode node) {
  if (node is YamlScalar) {
    if (node.style == ScalarStyle.LITERAL ||
        node.style == ScalarStyle.FOLDED ||
        node.style == ScalarStyle.ANY) {
      return true;
    }
  }

  if (node is YamlList &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) {
    return true;
  }
  if (node is YamlMap &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) {
    return true;
  }

  return false;
}

/// Checks if the item is a Map or a List
bool isCollection(Object item) => item is Map || item is List;

/// Checks if [index] is [int], >=0, < [length]
bool isValidIndex(Object? index, int length) {
  return index is int && index >= 0 && index < length;
}

/// Checks if the item is empty, if it is a List or a Map.
///
/// Returns `false` if [item] is not a List or Map.
bool isEmpty(Object item) {
  if (item is Map) return item.isEmpty;
  if (item is List) return item.isEmpty;

  return false;
}

/// Creates a [SourceSpan] from [sourceUrl] with no meaningful location
/// information.
///
/// Mainly used with [wrapAsYamlNode] to allow for a reasonable
/// implementation of [SourceSpan.message].
SourceSpan shellSpan(Object? sourceUrl) {
  final shellSourceLocation = SourceLocation(0, sourceUrl: sourceUrl);
  return SourceSpanBase(shellSourceLocation, shellSourceLocation, '');
}

/// Returns if [value] is a [YamlList] or [YamlMap] with [CollectionStyle.FLOW].
bool isFlowYamlCollectionNode(Object value) =>
    value is YamlNode && value.collectionStyle == CollectionStyle.FLOW;

/// Determines the index where [newKey] will be inserted if the keys in [map]
/// are in alphabetical order when converted to strings.
///
/// Returns the length of [map] if the keys in [map] are not in alphabetical
/// order.
int getMapInsertionIndex(YamlMap map, Object newKey) {
  final keys = map.nodes.keys.map((k) => k.toString()).toList();

  // Detect if the keys are not already sorted, append new entry to the end
  for (var i = 1; i < keys.length; i++) {
    if (keys[i].compareTo(keys[i - 1]) < 0) {
      return map.length;
    }
  }

  final newKeyString = newKey.toString();
  final insertionIndex =
      keys.indexWhere((key) => key.compareTo(newKeyString) > 0);

  if (insertionIndex != -1) return insertionIndex;

  return map.length;
}

/// Returns the detected line ending used in [yaml], more specifically, whether
/// [yaml] appears to use Windows `\r\n` or Unix `\n` line endings.
///
/// The heuristic used is to count all `\n` in the text and if strictly more
/// than half of them are preceded by `\r` we report that windows line endings
/// are used.
String getLineEnding(String yaml) {
  var index = -1;
  var unixNewlines = 0;
  var windowsNewlines = 0;
  while ((index = yaml.indexOf('\n', index + 1)) != -1) {
    if (index != 0 && yaml[index - 1] == '\r') {
      windowsNewlines++;
    } else {
      unixNewlines++;
    }
  }

  return windowsNewlines > unixNewlines ? '\r\n' : '\n';
}

extension YamlNodeExtension on YamlNode {
  /// Returns the [CollectionStyle] of `this` if `this` is [YamlMap] or
  /// [YamlList].
  ///
  /// Otherwise, returns `null`.
  CollectionStyle? get collectionStyle {
    final me = this;
    if (me is YamlMap) return me.style;
    if (me is YamlList) return me.style;
    return null;
  }
}
