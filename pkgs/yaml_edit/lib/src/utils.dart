// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'editor.dart';
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

/// Returns the content sensitive ending offset of [yamlNode] (i.e. where the
/// last meaningful content happens)
int getContentSensitiveEnd(YamlNode yamlNode) {
  if (yamlNode is YamlList) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.last);
    }
  } else if (yamlNode is YamlMap) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.values.last);
    }
  }

  return yamlNode.span.end.offset;
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

  // We can't deduce ordering if list is empty, so then we just we just append
  if (keys.length <= 1) {
    return map.length;
  }

  for (var i = 1; i < keys.length; i++) {
    if (keys[i].compareTo(keys[i - 1]) < 0) {
      return map.length;
    }
  }

  final insertionIndex =
      keys.indexWhere((key) => key.compareTo(newKey as String) > 0);

  if (insertionIndex != -1) return insertionIndex;

  return map.length;
}

/// Returns the detected indentation step used in [editor], or defaults to a
/// value of `2` if no indentation step can be detected.
///
/// Indentation step is determined by the difference in indentation of the
/// first block-styled yaml collection in the second level as compared to the
/// top-level elements. In the case where there are multiple possible
/// candidates, we choose the candidate closest to the start of [editor].
int getIndentation(YamlEditor editor) {
  final node = editor.parseAt([]);
  Iterable<YamlNode>? children;
  var indentation = 2;

  if (node is YamlMap && node.style == CollectionStyle.BLOCK) {
    children = node.nodes.values;
  } else if (node is YamlList && node.style == CollectionStyle.BLOCK) {
    children = node.nodes;
  }

  if (children != null) {
    for (final child in children) {
      var indent = 0;
      if (child is YamlList) {
        indent = getListIndentation(editor.toString(), child);
      } else if (child is YamlMap) {
        indent = getMapIndentation(editor.toString(), child);
      }

      if (indent != 0) indentation = indent;
    }
  }
  return indentation;
}

/// Gets the indentation level of [list]. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
///
/// Throws [UnsupportedError] if an empty block map is passed in.
int getListIndentation(String yaml, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (list.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  final lastHyphen = yaml.lastIndexOf('-', lastSpanOffset - 1);

  if (lastHyphen == 0) return lastHyphen;

  // Look for '\n' that's before hyphen
  final lastNewLine = yaml.lastIndexOf('\n', lastHyphen - 1);

  return lastHyphen - lastNewLine - 1;
}

/// Gets the indentation level of [map]. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (map.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block map');
  }

  /// Use the number of spaces between the last key and the newline as
  /// indentation.
  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  final lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  final lastQuestionMark = yaml.lastIndexOf('?', lastSpanOffset);

  if (lastQuestionMark == -1) {
    if (lastNewLine == -1) return lastSpanOffset;
    return lastSpanOffset - lastNewLine - 1;
  }

  /// If there is a question mark, it might be a complex key. Check if it
  /// is on the same line as the key node to verify.
  if (lastNewLine == -1) return lastQuestionMark;
  if (lastQuestionMark > lastNewLine) {
    return lastQuestionMark - lastNewLine - 1;
  }

  return lastSpanOffset - lastNewLine - 1;
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
