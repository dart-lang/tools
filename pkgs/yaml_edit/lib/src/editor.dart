// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'alias_behavior.dart';
import 'equality.dart';
import 'errors.dart';
import 'list_mutations.dart';
import 'map_mutations.dart';
import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';
import 'wrap.dart';

/// An interface for modifying [YAML][1] documents while preserving comments
/// and whitespaces.
///
/// YAML parsing is supported by `package:yaml`, and modifications are performed
/// as string operations. An error will be thrown if internal assertions fail -
/// such a situation should be extremely rare, and should only occur with
/// degenerate formatting.
///
/// Most modification methods require the user to pass in an `Iterable<Object>`
/// path that holds the keys/indices to navigate to the element.
///
/// **Example:**
/// ```yaml
/// a: 1
/// b: 2
/// c:
///   - 3
///   - 4
///   - {e: 5, f: [6, 7]}
/// ```
///
/// To get to `7`, our path will be `['c', 2, 'f', 1]`. The path for the base
/// object is the empty array `[]`. All modification methods will throw a
/// [ArgumentError] if the path provided is invalid. Note also that that the
/// order of elements in the path is important, and it should be arranged in
/// order of calling, with the first element being the first key or index to be
/// called.
///
/// In most modification methods, users are required to pass in a value to be
/// used for updating the YAML tree. This value is only allowed to either be a
/// valid scalar that is recognizable by YAML (i.e. `bool`, `String`, `List`,
/// `Map`, `num`, `null`) or a [YamlNode]. Should the user want to specify
/// the style to be applied to the value passed in, the user may wrap the value
/// using [wrapAsYamlNode] while passing in the appropriate `scalarStyle` or
/// `collectionStyle`. While we try to respect the style that is passed in,
/// there will be instances where the formatting will not result in valid YAML,
/// and as such we will fallback to a default formatting while preserving the
/// content.
///
/// To dump the YAML after all the modifications have been completed, simply
/// call [toString()].
///
/// [1]: https://yaml.org/
@sealed
class YamlEditor {
  final List<SourceEdit> _edits = [];

  /// List of [SourceEdit]s that have been applied to [_yaml] since the creation
  /// of this instance, in chronological order. Intended to be compatible with
  /// `package:analysis_server`.
  ///
  /// The [SourceEdit] objects can be serialized to JSON using the `toJSON`
  /// function, deserialized using [SourceEdit.fromJson], and applied to a
  /// string using the `apply` function. Multiple [SourceEdit]s can be applied
  /// to a string using [SourceEdit.applyAll].
  ///
  /// For more information, refer to the [SourceEdit] class.
  List<SourceEdit> get edits => [..._edits];

  /// Current YAML string.
  String _yaml;

  /// Root node of YAML AST.
  YamlNode _contents;

  /// Stores the list of nodes in [_contents] that are connected by aliases.
  ///
  /// When a node is anchored with an alias and subsequently referenced,
  /// the full content of the anchored node is thought to be copied in the
  /// following references.
  ///
  /// **Example:**
  /// ```dart
  /// a: &SS Sammy Sosa
  /// b: *SS
  /// ```
  ///
  /// is equivalent to
  ///
  /// ```dart
  /// a: Sammy Sosa
  /// b: Sammy Sosa
  /// ```
  ///
  /// As such, aliased nodes have to be treated with special caution when
  /// any modification is taking place.
  ///
  /// See 7.1 Alias Nodes: https://yaml.org/spec/1.2/spec.html#id2786196
  ///
  /// Defines how mutations behave when encountering YAML alias references or
  /// anchor definition nodes. Defaults to [AliasBehavior.disallow], which
  /// throws an [AliasException] on any modification touching an alias or
  /// anchor.
  final AliasBehavior aliasBehavior;

  /// See 7.1 Alias Nodes: https://yaml.org/spec/1.2/spec.html#id2786196
  Set<YamlNode> _aliases = {};

  /// Maps each aliased [YamlNode] to its anchor definition path (the first
  /// path where it was encountered during AST initialization DFS).
  Map<YamlNode, List<Object?>> _anchorPaths = {};

  /// Stores the true [SourceSpan] of alias reference tokens (`*name`) for
  /// each entry `(parentCollection, keyOrIndex)`.
  Map<_AliasEntryKey, SourceSpan> _aliasReferenceSpans = {};

  /// Returns the current YAML string.
  @override
  String toString() => _yaml;

  factory YamlEditor(String yaml,
          {AliasBehavior aliasBehavior = AliasBehavior.disallow}) =>
      YamlEditor._(yaml, aliasBehavior);

  YamlEditor._(this._yaml, this.aliasBehavior)
      : _contents = loadYamlNode(_yaml) {
    _initialize();
  }

  /// Traverses the YAML tree formed to detect alias nodes.
  void _initialize() {
    _aliases = Set.identity();
    _anchorPaths = Map.identity();
    _aliasReferenceSpans = {};

    /// Performs a DFS on [_contents] to detect alias nodes.
    final firstVisited = Map<YamlNode, List<Object?>>.identity();
    void collectAliases(YamlNode node, List<Object?> path) {
      if (!firstVisited.containsKey(node)) {
        firstVisited[node] = path;
        if (node is YamlMap) {
          node.nodes.forEach((key, value) {
            collectAliases(key as YamlNode, [...path, key]);
            collectAliases(value, [...path, key]);
          });
        } else if (node is YamlList) {
          for (var i = 0; i < node.length; i++) {
            collectAliases(node.nodes[i], [...path, i]);
          }
        }
      } else {
        _aliases.add(node);
        _anchorPaths[node] ??= firstVisited[node]!;
        if (path.isNotEmpty) {
          final parentCollection =
              _traverse(path.take(path.length - 1), checkAlias: false);
          final keyOrIndex = path.last;
          _aliasReferenceSpans[_AliasEntryKey(parentCollection, keyOrIndex)] =
              _computeAliasSpan(_yaml, parentCollection, keyOrIndex);
        }
      }
    }

    collectAliases(_contents, []);
  }

  SourceSpan _computeAliasSpan(
      String yaml, YamlNode parentCollection, Object? keyOrIndex) {
    int searchStart;
    if (parentCollection is YamlMap) {
      final keyNode = getKeyNode(parentCollection, keyOrIndex);
      searchStart = keyNode.span.end.offset;
    } else {
      final idx = keyOrIndex as int;
      if (idx > 0) {
        searchStart = getTrueContentSensitiveEnd(parentCollection, idx - 1);
      } else {
        searchStart = parentCollection.span.start.offset;
      }
    }

    var i = searchStart;
    while (i < yaml.length) {
      final ch = yaml.codeUnitAt(i);
      if (ch == 0x23) {
        while (i < yaml.length &&
            yaml.codeUnitAt(i) != 0x0A &&
            yaml.codeUnitAt(i) != 0x0D) {
          i++;
        }
      } else if (ch == 0x2A) {
        final starIndex = i;
        i++;
        while (i < yaml.length) {
          final c = yaml.codeUnitAt(i);
          if (c == 0x20 ||
              c == 0x09 ||
              c == 0x0A ||
              c == 0x0D ||
              c == 0x5B ||
              c == 0x5D ||
              c == 0x7B ||
              c == 0x7D ||
              c == 0x2C) {
            break;
          }
          i++;
        }
        return SourceSpanBase(SourceLocation(starIndex), SourceLocation(i),
            yaml.substring(starIndex, i));
      } else {
        i++;
      }
    }

    final node = parentCollection is YamlMap
        ? parentCollection
            .nodes[keyOrIndex is YamlNode ? keyOrIndex.value : keyOrIndex]!
        : (parentCollection as YamlList).nodes[keyOrIndex as int];
    return node.span;
  }

  /// Returns the true source span of the node at [keyOrIndex] inside
  /// [parentCollection]. For alias references (`*name`), returns the span
  /// of the alias token itself rather than the anchor definition.
  SourceSpan getTrueSpan(YamlNode parentCollection, Object? keyOrIndex,
      [YamlNode? valueNode]) {
    final aliasSpan =
        _aliasReferenceSpans[_AliasEntryKey(parentCollection, keyOrIndex)];
    if (aliasSpan != null) return aliasSpan;
    final node = valueNode ??
        (parentCollection is YamlMap
            ? parentCollection.nodes[keyOrIndex] ??
                getYamlMapEntry(parentCollection, keyOrIndex).valueNode
            : (parentCollection as YamlList).nodes[keyOrIndex as int]);
    return node.span;
  }

  /// Returns the true content-sensitive ending offset of the node at
  /// [keyOrIndex] inside [parentCollection].
  int getTrueContentSensitiveEnd(YamlNode parentCollection, Object? keyOrIndex,
      [YamlNode? valueNode]) {
    final aliasSpan =
        _aliasReferenceSpans[_AliasEntryKey(parentCollection, keyOrIndex)];
    if (aliasSpan != null) return aliasSpan.end.offset;
    final node = valueNode ??
        (parentCollection is YamlMap
            ? parentCollection.nodes[keyOrIndex] ??
                getYamlMapEntry(parentCollection, keyOrIndex).valueNode
            : (parentCollection as YamlList).nodes[keyOrIndex as int]);

    return _getContentSensitiveEndWithAliases(node);
  }

  int _getContentSensitiveEndWithAliases(YamlNode yamlNode,
      [Set<YamlNode>? visited]) {
    final activeVisited = visited ?? Set<YamlNode>.identity();
    if (!activeVisited.add(yamlNode)) {
      return yamlNode.span.end.offset;
    }

    if (yamlNode is YamlList) {
      if (yamlNode.style == CollectionStyle.FLOW || yamlNode.isEmpty) {
        return yamlNode.span.end.offset;
      } else {
        final lastIdx = yamlNode.length - 1;
        final lastItem = yamlNode.nodes[lastIdx];
        final aliasSpan =
            _aliasReferenceSpans[_AliasEntryKey(yamlNode, lastIdx)];
        if (aliasSpan != null) {
          if (activeVisited.contains(lastItem)) {
            return yamlNode.span.end.offset;
          }
          return aliasSpan.end.offset;
        }
        return _getContentSensitiveEndWithAliases(lastItem, activeVisited);
      }
    } else if (yamlNode is YamlMap) {
      if (yamlNode.style == CollectionStyle.FLOW || yamlNode.isEmpty) {
        return yamlNode.span.end.offset;
      } else {
        final lastKey = yamlNode.nodes.keys.last;
        final lastValue = yamlNode.nodes[lastKey]!;
        final aliasSpan =
            _aliasReferenceSpans[_AliasEntryKey(yamlNode, lastKey)];
        if (aliasSpan != null) {
          if (activeVisited.contains(lastValue)) {
            return yamlNode.span.end.offset;
          }
          return aliasSpan.end.offset;
        }
        return _getContentSensitiveEndWithAliases(lastValue, activeVisited);
      }
    }

    return yamlNode.span.end.offset;
  }

  /// Checks whether the child at [keyOrIndex] in [parentCollection] is an
  /// anchor definition node (`&anchor`).
  bool isAnchorDefinition(YamlNode parentCollection, Object? keyOrIndex) {
    final node = parentCollection is YamlMap
        ? parentCollection
            .nodes[keyOrIndex is YamlNode ? keyOrIndex.value : keyOrIndex]!
        : (parentCollection as YamlList).nodes[keyOrIndex as int];
    if (!_aliases.contains(node)) return false;
    final anchorPath = _anchorPaths[node];
    if (anchorPath == null) return false;
    return _aliasReferenceSpans[_AliasEntryKey(parentCollection, keyOrIndex)] ==
        null;
  }

  bool _isAliasReferenceNode(YamlNode node, Iterable<Object?> path) {
    if (!_aliases.contains(node)) return false;
    final anchorPath = _anchorPaths[node];
    if (anchorPath == null) return false;
    return !_pathsEqual(anchorPath, path);
  }

  bool _pathsEqual(Iterable<Object?> a, Iterable<Object?> b) {
    if (a.length != b.length) return false;
    final itA = a.iterator;
    final itB = b.iterator;
    while (itA.moveNext() && itB.moveNext()) {
      if (!deepEquals(itA.current, itB.current)) return false;
    }
    return true;
  }

  String _getTargetValueRepresentation(
    YamlNode parentCollection,
    Object? keyOrIndex,
    YamlNode targetNode,
    String anchorTag,
  ) {
    final span = getTrueSpan(parentCollection, keyOrIndex, targetNode);
    var text = span.text;
    if (text.startsWith('$anchorTag ')) {
      text = text.substring(anchorTag.length + 1);
    } else if (text.startsWith(anchorTag)) {
      text = text.substring(anchorTag.length);
    }

    if ((targetNode is YamlMap || targetNode is YamlList) &&
        !isFlowYamlCollectionNode(targetNode)) {
      if (!text.startsWith(RegExp(r'\r?\n'))) {
        text = '\n$text';
      }
      return text.trimRight();
    }

    return text.trim();
  }

  _IntraTemplateInfo _collectIntraTemplateAnchors(
    YamlNode anchorNode,
    List<Object?> anchorPath,
  ) {
    final anchorTags = <String>{};
    final anchorValues = <String, String>{};
    final visited = Set<YamlNode>.identity();

    void walk(YamlNode current, List<Object?> currentPath) {
      if (!visited.add(current)) return;

      if (current is YamlMap) {
        for (final entry in current.nodes.entries) {
          final key = entry.key;
          final value = entry.value;
          final unwrappedKey = key is YamlNode ? key.value : key;
          final childPath = [...currentPath, unwrappedKey];

          if (_isAliasReferenceNode(value, childPath)) {
            // Alias references do not define anchors here.
            continue;
          }

          final tag = getAnchorTag(current, key);
          if (tag != null) {
            anchorTags.add(tag);
            anchorValues[tag] =
                _getTargetValueRepresentation(current, key, value, tag);
          }

          if (value is YamlMap || value is YamlList) {
            walk(value, childPath);
          }
        }
      } else if (current is YamlList) {
        for (var i = 0; i < current.nodes.length; i++) {
          final item = current.nodes[i];
          final childPath = [...currentPath, i];

          if (_isAliasReferenceNode(item, childPath)) {
            // Alias references do not define anchors here.
            continue;
          }

          final tag = getAnchorTag(current, i);
          if (tag != null) {
            anchorTags.add(tag);
            anchorValues[tag] =
                _getTargetValueRepresentation(current, i, item, tag);
          }

          if (item is YamlMap || item is YamlList) {
            walk(item, childPath);
          }
        }
      }
    }

    walk(anchorNode, anchorPath);

    // Strip nested sub-anchor tags from anchor values.
    for (final tag in anchorValues.keys) {
      for (final subTag in anchorTags) {
        anchorValues[tag] = anchorValues[tag]!.replaceAll('$subTag ', '');
        anchorValues[tag] = anchorValues[tag]!.replaceAll(
          RegExp('${RegExp.escape(subTag)}\\r?\\n'),
          '\n',
        );
      }
    }

    // Resolve any nested intra-template aliases within anchor values.
    for (final tag in anchorValues.keys) {
      for (final otherTag in anchorValues.keys) {
        final name = otherTag.substring(1);
        final val = anchorValues[otherTag]!;
        if (val.startsWith(RegExp(r'\r?\n'))) {
          anchorValues[tag] = anchorValues[tag]!.replaceAll(
            RegExp(r'[ \t]*\*' + RegExp.escape(name) + r'(?![a-zA-Z0-9_-])'),
            val,
          );
        } else {
          anchorValues[tag] = anchorValues[tag]!.replaceAll(
            RegExp(r'\*' + RegExp.escape(name) + r'(?![a-zA-Z0-9_-])'),
            val,
          );
        }
      }
    }

    return _IntraTemplateInfo(anchorTags, anchorValues);
  }

  String _getUnfoldedText(
    YamlNode parentOfAnchor,
    Object? keyOfAnchor,
    YamlNode anchorNode,
    int targetIndentation,
    String lineEnding, {
    List<Object?>? anchorPath,
  }) {
    final span = getTrueSpan(parentOfAnchor, keyOfAnchor, anchorNode);
    var text = span.text;

    // Strip top-level anchor definition tag (`&anchorName\n` or `&anchorName `).
    if (text.startsWith('&')) {
      final wsIdx = text.indexOf(RegExp(r'\s'));
      if (wsIdx != -1) {
        text = text.substring(wsIdx);
      } else {
        text = '';
      }
    }

    final resolvedAnchorPath = anchorPath ?? _anchorPaths[anchorNode] ?? [];
    final intraInfo =
        _collectIntraTemplateAnchors(anchorNode, resolvedAnchorPath);

    // Strip nested intra-template sub-anchor definition tags to prevent
    // duplicate anchor definitions.
    for (final tag in intraInfo.anchorTags) {
      text = text.replaceAll('$tag ', '');
      text = text.replaceAll(RegExp('${RegExp.escape(tag)}\\r?\\n'), '\n');
    }

    // Expand intra-template alias references inline so the decoupled copy is
    // completely self-contained.
    final sortedTags = intraInfo.anchorValues.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final tag in sortedTags) {
      final targetValue = intraInfo.anchorValues[tag]!;
      final anchorName = tag.substring(1);
      if (targetValue.startsWith(RegExp(r'\r?\n'))) {
        final aliasRegex = RegExp(
            r'[ \t]*\*' + RegExp.escape(anchorName) + r'(?![a-zA-Z0-9_-])');
        text = text.replaceAll(aliasRegex, targetValue);
      } else {
        final aliasRegex =
            RegExp(r'\*' + RegExp.escape(anchorName) + r'(?![a-zA-Z0-9_-])');
        text = text.replaceAll(aliasRegex, targetValue);
      }
    }

    if (anchorNode is YamlMap || anchorNode is YamlList) {
      if (isFlowYamlCollectionNode(anchorNode)) {
        return text.trim();
      }

      // Block collection: split into lines and re-indent
      final lines = text.trimRight().split(RegExp(r'\r?\n'));
      int? baseIndent;
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          final leadingSpaces = line.length - line.trimLeft().length;
          if (baseIndent == null || leadingSpaces < baseIndent) {
            baseIndent = leadingSpaces;
          }
        }
      }

      baseIndent ??= 0;
      final reindentedLines = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) {
          if (i > 0 && i < lines.length - 1) reindentedLines.add('');
          continue;
        }
        final leadingSpaces = line.length - line.trimLeft().length;
        final relIndent = leadingSpaces - baseIndent;
        final newIndent = targetIndentation + relIndent;
        reindentedLines
            .add((' ' * (newIndent > 0 ? newIndent : 0)) + line.trimLeft());
      }

      var result = reindentedLines.join(lineEnding);
      if (text.startsWith(RegExp(r'\r?\n'))) {
        result = lineEnding + result;
      }
      return result;
    }

    return text.trim();
  }

  void _materializeAliasReference(Iterable<Object?> aliasPath) {
    final pathList = aliasPath.toList();
    final parentPath = pathList.take(pathList.length - 1);
    final keyOrIndex = pathList.last;
    final parentCollection = _traverse(parentPath, checkAlias: false);
    final node = _traverse(aliasPath, checkAlias: false);
    final anchorPath = _anchorPaths[node]!;

    final anchorParentPath = anchorPath.take(anchorPath.length - 1);
    final anchorKeyOrIndex = anchorPath.last;
    final anchorParent = _traverse(anchorParentPath, checkAlias: false);
    final anchorNode = _traverse(anchorPath, checkAlias: false);

    final lineEnding = getLineEnding(_yaml);
    var targetIndentation = 0;
    if (parentCollection is YamlMap) {
      targetIndentation =
          getMapIndentation(_yaml, parentCollection) + getIndentation(this);
    } else if (parentCollection is YamlList) {
      targetIndentation =
          getListIndentation(_yaml, parentCollection) + getIndentation(this);
    }

    final unfoldedText = _getUnfoldedText(
      anchorParent,
      anchorKeyOrIndex,
      anchorNode,
      targetIndentation,
      lineEnding,
      anchorPath: anchorPath,
    );

    final aliasSpan = getTrueSpan(parentCollection, keyOrIndex, node);
    var start = aliasSpan.start.offset;
    var length = aliasSpan.length;
    var replacement = unfoldedText;

    if (unfoldedText.startsWith(lineEnding) &&
        start > 0 &&
        _yaml[start - 1] == ' ') {
      start -= 1;
      length += 1;
    }

    final edit = SourceEdit(start, length, replacement);
    _performEdit(edit, aliasPath, anchorNode);
  }

  Iterable<Object?> _resolvePath(Iterable<Object?> path,
      {bool resolveLeaf = false}) {
    final pathList = path.toList();
    if (pathList.isEmpty) return pathList;

    final maxIdx = resolveLeaf ? pathList.length : pathList.length - 1;
    for (var i = 0; i < maxIdx; i++) {
      final subPath = pathList.take(i + 1).toList();
      final node = _traverse(subPath, checkAlias: false);
      if (_isAliasReferenceNode(node, subPath)) {
        if (aliasBehavior == AliasBehavior.disallow) {
          throw AliasException(path, node);
        } else if (aliasBehavior == AliasBehavior.reference) {
          final anchorPath = _anchorPaths[node]!;
          final redirectedPath = [...anchorPath, ...pathList.skip(i + 1)];
          return _resolvePath(redirectedPath, resolveLeaf: resolveLeaf);
        } else if (aliasBehavior == AliasBehavior.copyOnWrite) {
          _materializeAliasReference(subPath);
          return _resolvePath(path, resolveLeaf: resolveLeaf);
        }
      }
    }
    return pathList;
  }

  /// Parses the document to return [YamlNode] currently present at [path].
  ///
  /// If no [YamlNode]s exist at [path], the result of invoking the [orElse]
  /// function is returned.
  ///
  /// If [orElse] is omitted, it defaults to throwing a [ArgumentError].
  ///
  /// To get a default value when [path] does not point to a value in the
  /// [YamlNode]-tree, simply pass `orElse: () => ...`.
  ///
  /// **Example:** (using orElse)
  /// ```dart
  /// final myYamlEditor('{"key": "value"}');
  /// final node = myYamlEditor.valueAt(
  ///   ['invalid', 'path'],
  ///   orElse: () => wrapAsYamlNode(null),
  /// );
  /// print(node.value); // null
  /// ```
  ///
  /// **Example:** (common usage)
  /// ```dart
  ///   final doc = YamlEditor('''
  /// a: 1
  /// b:
  ///   d: 4
  ///   e: [5, 6, 7]
  /// c: 3
  /// ''');
  /// print(doc.parseAt(['b', 'e', 2])); // 7
  /// ```
  /// The value returned by [parseAt] is invalidated when the documented is
  /// mutated, as illustrated below:
  ///
  /// **Example:** (old [parseAt] value is invalidated)
  /// ```dart
  /// final doc = YamlEditor("YAML: YAML Ain't Markup Language");
  /// final node = doc.parseAt(['YAML']);
  ///
  /// print(node.value); // Expected output: "YAML Ain't Markup Language"
  ///
  /// doc.update(['YAML'], 'YAML');
  ///
  /// final newNode = doc.parseAt(['YAML']);
  ///
  /// // Note that the value does not change
  /// print(newNode.value); // "YAML"
  /// print(node.value); // "YAML Ain't Markup Language"
  /// ```
  YamlNode parseAt(Iterable<Object?> path, {YamlNode Function()? orElse}) {
    return _traverse(path, orElse: orElse);
  }

  /// Sets [value] in the [path].
  ///
  /// There is a subtle difference between [update] and [remove] followed by
  /// an [insertIntoList], because [update] preserves comments at the same
  /// level.
  ///
  /// Throws a [ArgumentError] if [path] is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:** (using [update])
  /// ```dart
  /// final doc = YamlEditor('''
  ///   - 0
  ///   - 1 # comment
  ///   - 2
  /// ''');
  /// doc.update([1], 'test');
  /// ```
  ///
  /// **Expected Output:**
  /// ```yaml
  ///   - 0
  ///   - test # comment
  ///   - 2
  /// ```
  ///
  /// **Example:** (using [remove] and [insertIntoList])
  /// ```dart
  /// final doc2 = YamlEditor('''
  ///   - 0
  ///   - 1 # comment
  ///   - 2
  /// ''');
  /// doc2.remove([1]);
  /// doc2.insertIntoList([], 1, 'test');
  /// ```
  ///
  /// **Expected Output:**
  /// ```yaml
  ///   - 0
  ///   - test
  ///   - 2
  /// ```
  void update(Iterable<Object?> path, Object? value) {
    path = _resolvePath(path);
    final valueNode = wrapAsYamlNode(value);

    if (path.isEmpty) {
      final start = _contents.span.start.offset;
      final end = getContentSensitiveEnd(_contents);
      final lineEnding = getLineEnding(_yaml);
      final edit = SourceEdit(
          start, end - start, yamlEncodeBlock(valueNode, 0, lineEnding));

      return _performEdit(edit, path, valueNode);
    }

    final pathAsList = path.toList();
    final collectionPath = pathAsList.take(path.length - 1);
    final keyOrIndex = pathAsList.last;
    final parentNode = _traverse(
      collectionPath,
      checkAlias: aliasBehavior == AliasBehavior.disallow,
    );

    if (aliasBehavior == AliasBehavior.disallow &&
        _aliases.contains(parentNode)) {
      throw AliasException(path, parentNode);
    }

    if (parentNode is YamlList) {
      if (keyOrIndex is! int) {
        throw PathError(path, path, parentNode);
      }
      if (isValidIndex(keyOrIndex, parentNode.length) &&
          aliasBehavior == AliasBehavior.disallow &&
          _aliases.contains(parentNode.nodes[keyOrIndex])) {
        throw AliasException(path, parentNode.nodes[keyOrIndex]);
      }
      final expectedList = [...parentNode.nodes]..[keyOrIndex] = valueNode;
      if (aliasBehavior != AliasBehavior.disallow) {
        for (var i = 0; i < expectedList.length; i++) {
          if (i != keyOrIndex &&
              _isAliasReferenceNode(
                  parentNode.nodes[i], [...collectionPath, i])) {
            final anchorPath = _anchorPaths[parentNode.nodes[i]]!;
            if (_pathsEqual(anchorPath, [...collectionPath, keyOrIndex])) {
              expectedList[i] = valueNode;
            }
          }
        }
      }
      final expected = wrapAsYamlNode(expectedList);
      if (aliasBehavior != AliasBehavior.disallow && expected is YamlListWrap) {
        for (var i = 0; i < expectedList.length; i++) {
          if (_isAliasReferenceNode(
              parentNode.nodes[i], [...collectionPath, i])) {
            final anchorPath = _anchorPaths[parentNode.nodes[i]]!;
            if (_pathsEqual(anchorPath, collectionPath)) {
              expected.nodes[i] = expected;
            }
          }
        }
      }

      return _performEdit(updateInList(this, parentNode, keyOrIndex, valueNode),
          collectionPath, expected);
    }

    if (parentNode is YamlMap) {
      if (aliasBehavior == AliasBehavior.disallow &&
          containsKey(parentNode, keyOrIndex) &&
          _aliases.contains(parentNode.nodes[keyOrIndex])) {
        throw AliasException(path, parentNode.nodes[keyOrIndex]!);
      }
      final expectedMap = updatedYamlMap(parentNode, (nodes) {
        nodes[keyOrIndex] = valueNode;
        if (aliasBehavior != AliasBehavior.disallow) {
          for (final k in nodes.keys.toList()) {
            if (!deepEquals(k, keyOrIndex) &&
                nodes[k] is YamlNode &&
                _isAliasReferenceNode(
                    nodes[k] as YamlNode, [...collectionPath, k])) {
              final anchorPath = _anchorPaths[nodes[k]]!;
              if (_pathsEqual(anchorPath, [...collectionPath, keyOrIndex])) {
                nodes[k] = valueNode;
              }
            }
          }
        }
      });

      if (aliasBehavior != AliasBehavior.disallow &&
          expectedMap is YamlMapWrap) {
        for (final entry in parentNode.nodes.entries) {
          final k = entry.key;
          final node = entry.value;
          if (_isAliasReferenceNode(node, [...collectionPath, k])) {
            final anchorPath = _anchorPaths[node]!;
            if (_pathsEqual(anchorPath, collectionPath)) {
              final keyNode = getKeyNode(expectedMap, k);
              expectedMap.nodes[keyNode] = expectedMap;
            }
          }
        }
      }

      return _performEdit(updateInMap(this, parentNode, keyOrIndex, valueNode),
          collectionPath, expectedMap);
    }

    throw PathError.unexpected(
        path, 'Scalar $parentNode does not have key $keyOrIndex');
  }

  /// Appends [value] to the list at [path].
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[0, 1]');
  /// doc.appendToList([], 2); // [0, 1, 2]
  /// ```
  void appendToList(Iterable<Object?> path, Object? value) {
    path = _resolvePath(path, resolveLeaf: true);
    final yamlList = _traverseToList(
      path,
      checkAlias: aliasBehavior == AliasBehavior.disallow,
    );

    insertIntoList(path, yamlList.length, value);
  }

  /// Prepends [value] to the list at [path].
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[1, 2]');
  /// doc.prependToList([], 0); // [0, 1, 2]
  /// ```
  void prependToList(Iterable<Object?> path, Object? value) {
    path = _resolvePath(path, resolveLeaf: true);
    insertIntoList(path, 0, value);
  }

  /// Inserts [value] into the list at [path].
  ///
  /// [index] must be non-negative and no greater than the list's length.
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[0, 2]');
  /// doc.insertIntoList([], 1, 1); // [0, 1, 2]
  /// ```
  void insertIntoList(Iterable<Object?> path, int index, Object? value) {
    path = _resolvePath(path, resolveLeaf: true);
    final valueNode = wrapAsYamlNode(value);

    final list = _traverseToList(
      path,
      checkAlias: aliasBehavior == AliasBehavior.disallow,
    );
    RangeError.checkValueInInterval(index, 0, list.length);

    final edit = insertInList(this, list, index, valueNode);
    final expected = wrapAsYamlNode(
      [...list.nodes]..insert(index, valueNode),
    );

    _performEdit(edit, path, expected);
  }

  /// Changes the contents of the list at [path] by removing [deleteCount]
  /// items at [index], and inserting [values] in-place. Returns the elements
  /// that are deleted.
  ///
  /// [index] and [deleteCount] must be non-negative and [index] + [deleteCount]
  /// must be no greater than the list's length.
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[Jan, March, April, June]');
  /// doc.spliceList([], 1, 0, ['Feb']); // [Jan, Feb, March, April, June]
  /// doc.spliceList([], 4, 1, ['May']); // [Jan, Feb, March, April, May]
  /// ```
  Iterable<YamlNode> spliceList(Iterable<Object?> path, int index,
      int deleteCount, Iterable<Object?> values) {
    path = _resolvePath(path, resolveLeaf: true);
    final list = _traverseToList(
      path,
      checkAlias: aliasBehavior == AliasBehavior.disallow,
    );

    RangeError.checkValueInInterval(index, 0, list.length);
    RangeError.checkValueInInterval(index + deleteCount, 0, list.length);

    final nodesToRemove = list.nodes.getRange(index, index + deleteCount);

    // Perform addition of elements before removal to avoid scenarios where
    // a block list gets emptied out to {} to avoid changing collection styles
    // where possible.

    // Reverse [values] and insert them.
    final reversedValues = values.toList().reversed;
    for (final value in reversedValues) {
      insertIntoList(path, index, value);
    }

    for (var i = 0; i < deleteCount; i++) {
      remove([...path, index + values.length]);
    }

    return nodesToRemove;
  }

  /// Removes the node at [path].
  ///
  /// Throws a [PathError] if the path is invalid.
  ///
  /// When [aliasBehavior] is [AliasBehavior.disallow], throws an
  /// [AliasException] if a node along [path] is an alias reference or anchor
  /// definition. For other [AliasBehavior] modes, see [AliasBehavior] for
  /// redirection and Copy-On-Write semantics.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[0, 1]');
  /// doc.remove([1]); // [0]
  /// ```
  YamlNode remove(Iterable<Object?> path) {
    path = _resolvePath(path);
    SourceEdit edit;
    YamlNode expectedNode;
    final nodeToRemove = _traverse(
      path,
      checkAlias: aliasBehavior == AliasBehavior.disallow,
    );

    if (aliasBehavior != AliasBehavior.disallow &&
        _aliases.contains(nodeToRemove) &&
        _anchorPaths[nodeToRemove] != null &&
        _pathsEqual(_anchorPaths[nodeToRemove]!, path) &&
        _hasActiveReferencesToAnchor(nodeToRemove)) {
      throw AliasException(path, nodeToRemove);
    }

    if (path.isEmpty) {
      edit = SourceEdit(0, _yaml.length, '');
      _performEdit(edit, path, wrapAsYamlNode(null));
      return nodeToRemove;
    }

    final pathList = path.toList();
    final collectionPath = pathList.take(path.length - 1);
    final keyOrIndex = pathList.last;
    final parentNode = _traverse(collectionPath,
        checkAlias: aliasBehavior == AliasBehavior.disallow);

    if (aliasBehavior == AliasBehavior.disallow &&
        _aliases.contains(parentNode)) {
      throw AliasException(path, parentNode);
    }

    if (parentNode is YamlList) {
      edit = removeInList(this, parentNode, keyOrIndex as int);
      expectedNode = wrapAsYamlNode(
        [...parentNode.nodes]..removeAt(keyOrIndex),
      );
    } else if (parentNode is YamlMap) {
      edit = removeInMap(this, parentNode, keyOrIndex);

      expectedNode =
          updatedYamlMap(parentNode, (nodes) => nodes.remove(keyOrIndex));
    } else {
      throw PathError.unexpected(
          path, 'Scalar $parentNode does not have key $keyOrIndex');
    }

    _performEdit(edit, collectionPath, expectedNode);

    return nodeToRemove;
  }

  /// Traverses down [path] to return the [YamlNode] at [path] if successful.
  YamlNode _traverse(Iterable<Object?> path,
      {bool checkAlias = false, YamlNode Function()? orElse}) {
    if (path.isEmpty) return _contents;

    var currentNode = _contents;
    final pathList = path.toList();

    for (var i = 0; i < pathList.length; i++) {
      final keyOrIndex = pathList[i];

      if (checkAlias && _aliases.contains(currentNode)) {
        throw AliasException(path, currentNode);
      }

      if (currentNode is YamlList) {
        final list = currentNode;
        if (!isValidIndex(keyOrIndex, list.length)) {
          return _pathErrorOrElse(path, path.take(i + 1), list, orElse);
        }

        currentNode = list.nodes[keyOrIndex as int];
      } else if (currentNode is YamlMap) {
        final map = currentNode;

        if (!containsKey(map, keyOrIndex)) {
          return _pathErrorOrElse(path, path.take(i + 1), map, orElse);
        }
        final keyNode = getKeyNode(map, keyOrIndex);

        if (checkAlias) {
          if (_aliases.contains(keyNode)) throw AliasException(path, keyNode);
        }

        currentNode = map.nodes[keyNode]!;
      } else {
        return _pathErrorOrElse(path, path.take(i + 1), currentNode, orElse);
      }
    }

    if (checkAlias) _assertNoChildAlias(path, currentNode);

    return currentNode;
  }

  /// Throws a [PathError] if [orElse] is not provided, returns the result
  /// of invoking the [orElse] function otherwise.
  YamlNode _pathErrorOrElse(Iterable<Object?> path, Iterable<Object?> subPath,
      YamlNode parent, YamlNode Function()? orElse) {
    if (orElse == null) throw PathError(path, subPath, parent);
    return orElse();
  }

  /// Asserts that [node] and none its children are aliases
  void _assertNoChildAlias(Iterable<Object?> path, [YamlNode? node]) {
    if (node == null) return _assertNoChildAlias(path, _traverse(path));
    if (_aliases.contains(node)) throw AliasException(path, node);

    if (node is YamlScalar) return;

    if (node is YamlList) {
      for (var i = 0; i < node.length; i++) {
        final updatedPath = [...path, i];
        _assertNoChildAlias(updatedPath, node.nodes[i]);
      }
    }

    if (node is YamlMap) {
      final keyList = node.keys.toList();
      for (var i = 0; i < node.length; i++) {
        final updatedPath = [...path, keyList[i]];
        if (_aliases.contains(keyList[i])) {
          throw AliasException(path, keyList[i] as YamlNode);
        }
        _assertNoChildAlias(updatedPath, node.nodes[keyList[i]]);
      }
    }
  }

  /// Traverses down the provided [path] to return the [YamlList] at [path].
  ///
  /// Convenience function to ensure that a [YamlList] is returned.
  ///
  /// Throws [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid. If [checkAlias] is `true`, and an
  /// aliased node is encountered along [path], an [AliasException] will be
  /// thrown.
  YamlList _traverseToList(Iterable<Object?> path, {bool checkAlias = false}) {
    final possibleList = _traverse(path, checkAlias: checkAlias);

    if (possibleList is YamlList) {
      return possibleList;
    } else {
      throw PathError.unexpected(
          path, 'Path $path does not point to a YamlList!');
    }
  }

  /// Utility method to replace the substring of [_yaml] according to [edit].
  ///
  /// When [_yaml] is modified with this method, the resulting string is parsed
  /// and reloaded and traversed down [path] to ensure that the reloaded YAML
  /// tree is equal to our expectations by deep equality of values. Throws an
  /// [AssertionError] if the two trees do not match.
  void _performEdit(
    SourceEdit edit,
    Iterable<Object?> path,
    YamlNode expectedNode,
  ) {
    final expectedTree = _deepModify(_contents, path, [], expectedNode);
    final initialYaml = _yaml;
    final updatedYaml = edit.apply(_yaml);

    // Check that the edit does actually parse
    final YamlNode actualTree;
    try {
      actualTree = withYamlWarningCallback(() => loadYamlNode(updatedYaml));
    } on YamlException {
      throw createAssertionError(
        'Failed to produce valid YAML after modification.',
        initialYaml,
        updatedYaml,
      );
    }

    // Check that the edit is semantically correct
    if (!deepEquals(actualTree, expectedTree)) {
      throw createAssertionError(
        'Modification did not result in expected result.',
        initialYaml,
        updatedYaml,
      );
    }

    // Update state of YamlEditor, when we've validated that the edit was
    // semantically correct!
    _yaml = updatedYaml;
    _contents = actualTree;
    _edits.add(edit);
    _initialize(); // update tracking of aliases
  }

  bool _hasActiveReferencesToAnchor(YamlNode anchorNode) {
    final anchorPath = _anchorPaths[anchorNode];
    if (anchorPath == null) return false;

    final visited = Set<YamlNode>.identity();
    var hasReference = false;
    void checkNode(YamlNode node, List<Object?> currentPath) {
      if (hasReference) return;
      if (_aliases.contains(node) &&
          !_pathsEqual(currentPath, anchorPath) &&
          _pathsEqual(_anchorPaths[node]!, anchorPath)) {
        hasReference = true;
        return;
      }
      if (!visited.add(node)) return;

      if (node is YamlMap) {
        node.nodes.forEach((k, v) {
          checkNode(k as YamlNode, [...currentPath, k]);
          checkNode(v, [...currentPath, k]);
        });
      } else if (node is YamlList) {
        for (var i = 0; i < node.length; i++) {
          checkNode(node.nodes[i], [...currentPath, i]);
        }
      }
    }

    checkNode(_contents, []);
    return hasReference;
  }

  /// Returns the clean anchor tag (`&anchorName`) associated with the node
  /// at [keyOrIndex] inside [parentCollection], or `null` if none exists.
  String? getAnchorTag(YamlNode parentCollection, Object? keyOrIndex) {
    final unwrappedKey = keyOrIndex is YamlNode ? keyOrIndex.value : keyOrIndex;
    if (_aliasReferenceSpans[_AliasEntryKey(parentCollection, unwrappedKey)] !=
        null) {
      return null;
    }
    final span = getTrueSpan(parentCollection, unwrappedKey);
    final text = span.text;
    if (text.startsWith('&')) {
      final idx = text.indexOf(RegExp(r'\s'));
      if (idx != -1) {
        return text.substring(0, idx);
      }
      return text;
    }
    return null;
  }

  /// Utility method to produce an updated YAML tree equivalent to converting
  /// the [YamlNode] at [path] to be [expectedNode]. [subPath] holds the portion
  /// of [path] that has been traversed thus far.
  ///
  /// Throws a [PathError] if path is invalid.
  ///
  /// When called, it creates a new [YamlNode] of the same type as [tree], and
  /// copies its children over, except for the child that is on the path. Doing
  /// so allows us to "update" the immutable [YamlNode] without having to clone
  /// the whole tree.
  ///
  /// [SourceSpan]s in this new tree are not guaranteed to be accurate.
  YamlNode _deepModify(YamlNode tree, Iterable<Object?> path,
      Iterable<Object?> subPath, YamlNode expectedNode) {
    return _updateNodeAndAliases(
        tree, path.toList(), subPath.toList(), expectedNode);
  }

  YamlNode _updateNodeAndAliases(
    YamlNode tree,
    List<Object?> targetPath,
    List<Object?> currentPath,
    YamlNode expectedNode, [
    Set<YamlNode>? visited,
  ]) {
    final isOnTargetPath = currentPath.length <= targetPath.length &&
        _pathsEqual(currentPath, targetPath.take(currentPath.length));

    if (isOnTargetPath && currentPath.length == targetPath.length) {
      return expectedNode;
    }

    final activeVisited = visited ?? Set<YamlNode>.identity();
    if (!activeVisited.add(tree)) {
      return tree;
    }

    try {
      final keyOrIndex = isOnTargetPath ? targetPath[currentPath.length] : null;

      if (tree is YamlList) {
        if (isOnTargetPath && !isValidIndex(keyOrIndex, tree.length)) {
          throw PathError(targetPath, currentPath, tree);
        }

        final newNodes = <YamlNode>[];
        for (var i = 0; i < tree.length; i++) {
          final item = tree.nodes[i];
          if (isOnTargetPath && i == keyOrIndex) {
            newNodes.add(_updateNodeAndAliases(
              item,
              targetPath,
              [...currentPath, i],
              expectedNode,
              activeVisited,
            ));
          } else if (aliasBehavior != AliasBehavior.disallow &&
              _isAliasReferenceNode(item, [...currentPath, i])) {
            final anchorPath = _anchorPaths[item]!;
            if (targetPath.length >= anchorPath.length &&
                _pathsEqual(targetPath.take(anchorPath.length), anchorPath)) {
              newNodes.add(_updateNodeAndAliases(
                item,
                targetPath,
                anchorPath,
                expectedNode,
                activeVisited,
              ));
            } else {
              newNodes.add(item);
            }
          } else if (aliasBehavior != AliasBehavior.disallow &&
              (item is YamlMap || item is YamlList)) {
            newNodes.add(_updateNodeAndAliases(
              item,
              targetPath,
              [...currentPath, i],
              expectedNode,
              activeVisited,
            ));
          } else {
            newNodes.add(item);
          }
        }
        return wrapAsYamlNode(newNodes);
      }

      if (tree is YamlMap) {
        if (isOnTargetPath && !containsKey(tree, keyOrIndex)) {
          throw PathError(targetPath, currentPath, tree);
        }
        final newMap = <Object?, Object?>{};
        for (final entry in tree.nodes.entries) {
          final key = entry.key;
          final item = entry.value;
          if (isOnTargetPath && deepEquals(key, keyOrIndex)) {
            newMap[key] = _updateNodeAndAliases(
              item,
              targetPath,
              [...currentPath, key],
              expectedNode,
              activeVisited,
            );
          } else if (aliasBehavior != AliasBehavior.disallow &&
              _isAliasReferenceNode(item, [...currentPath, key])) {
            final anchorPath = _anchorPaths[item]!;
            if (targetPath.length >= anchorPath.length &&
                _pathsEqual(targetPath.take(anchorPath.length), anchorPath)) {
              newMap[key] = _updateNodeAndAliases(
                item,
                targetPath,
                anchorPath,
                expectedNode,
                activeVisited,
              );
            } else {
              newMap[key] = item;
            }
          } else if (aliasBehavior != AliasBehavior.disallow &&
              (item is YamlMap || item is YamlList)) {
            newMap[key] = _updateNodeAndAliases(
              item,
              targetPath,
              [...currentPath, key],
              expectedNode,
              activeVisited,
            );
          } else {
            newMap[key] = item;
          }
        }
        return wrapAsYamlNode(newMap);
      }

      if (isOnTargetPath) {
        throw PathError(targetPath, currentPath, tree);
      }
      return tree;
    } finally {
      activeVisited.remove(tree);
    }
  }
}

final class _AliasEntryKey {
  final YamlNode parent;
  final Object? keyOrIndex;

  _AliasEntryKey(this.parent, Object? keyOrIndex)
      : keyOrIndex = keyOrIndex is YamlNode ? keyOrIndex.value : keyOrIndex;

  @override
  bool operator ==(Object other) =>
      other is _AliasEntryKey &&
      parent == other.parent &&
      deepEquals(keyOrIndex, other.keyOrIndex);

  @override
  int get hashCode => parent.hashCode ^ keyOrIndex.hashCode;
}

final class _IntraTemplateInfo {
  final Set<String> anchorTags;
  final Map<String, String> anchorValues;

  _IntraTemplateInfo(this.anchorTags, this.anchorValues);
}
