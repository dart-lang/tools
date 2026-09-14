// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

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
  Set<YamlNode> _aliases = {};

  /// Returns the current YAML string.
  @override
  String toString() => _yaml;

  factory YamlEditor(String yaml) => YamlEditor._(yaml);

  YamlEditor._(this._yaml) : _contents = loadYamlNode(_yaml) {
    _initialize();
  }

  /// Traverses the YAML tree formed to detect alias nodes.
  void _initialize() {
    _aliases = {};

    /// Performs a DFS on [_contents] to detect alias nodes.
    final visited = <YamlNode>{};
    void collectAliases(YamlNode node) {
      if (visited.add(node)) {
        if (node is YamlMap) {
          node.nodes.forEach((key, value) {
            collectAliases(key as YamlNode);
            collectAliases(value);
          });
        } else if (node is YamlList) {
          node.nodes.forEach(collectAliases);
        }
      } else {
        _aliases.add(node);
      }
    }

    collectAliases(_contents);
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
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
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
    final parentNode = _traverse(collectionPath, checkAlias: true);

    if (parentNode is YamlList) {
      if (keyOrIndex is! int) {
        throw PathError(path, path, parentNode);
      }
      final expected = wrapAsYamlNode(
        [...parentNode.nodes]..[keyOrIndex] = valueNode,
      );

      return _performEdit(updateInList(this, parentNode, keyOrIndex, valueNode),
          collectionPath, expected);
    }

    if (parentNode is YamlMap) {
      final expectedMap =
          updatedYamlMap(parentNode, (nodes) => nodes[keyOrIndex] = valueNode);
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
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[0, 1]');
  /// doc.appendToList([], 2); // [0, 1, 2]
  /// ```
  void appendToList(Iterable<Object?> path, Object? value) {
    final yamlList = _traverseToList(path);

    insertIntoList(path, yamlList.length, value);
  }

  /// Prepends [value] to the list at [path].
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[1, 2]');
  /// doc.prependToList([], 0); // [0, 1, 2]
  /// ```
  void prependToList(Iterable<Object?> path, Object? value) {
    insertIntoList(path, 0, value);
  }

  /// Inserts [value] into the list at [path].
  ///
  /// [index] must be non-negative and no greater than the list's length.
  ///
  /// Throws a [ArgumentError] if the element at the given path is not a
  /// [YamlList] or if the path is invalid.
  ///
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[0, 2]');
  /// doc.insertIntoList([], 1, 1); // [0, 1, 2]
  /// ```
  void insertIntoList(Iterable<Object?> path, int index, Object? value) {
    final valueNode = wrapAsYamlNode(value);

    final list = _traverseToList(path, checkAlias: true);
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
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('[Jan, March, April, June]');
  /// doc.spliceList([], 1, 0, ['Feb']); // [Jan, Feb, March, April, June]
  /// doc.spliceList([], 4, 1, ['May']); // [Jan, Feb, March, April, May]
  /// ```
  Iterable<YamlNode> spliceList(Iterable<Object?> path, int index,
      int deleteCount, Iterable<Object?> values) {
    final list = _traverseToList(path, checkAlias: true);

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

  /// Removes the node at [path]. Comments "belonging" to the node will be
  /// removed while surrounding comments will be left untouched.
  ///
  /// Throws an [ArgumentError] if [path] is invalid.
  ///
  /// Throws an [AliasException] if a node on [path] is an alias or anchor.
  ///
  /// **Example:**
  /// ```dart
  /// final doc = YamlEditor('''
  /// - 0 # comment 0
  /// # comment A
  /// - 1 # comment 1
  /// # comment B
  /// - 2 # comment 2
  /// ''');
  /// doc.remove([1]);
  /// ```
  ///
  /// **Expected Result:**
  /// ```dart
  /// '''
  /// - 0 # comment 0
  /// # comment A
  /// # comment B
  /// - 2 # comment 2
  /// '''
  /// ```
  YamlNode remove(Iterable<Object?> path) {
    late SourceEdit edit;
    late YamlNode expectedNode;
    final nodeToRemove = _traverse(path, checkAlias: true);

    if (path.isEmpty) {
      edit = SourceEdit(0, _yaml.length, '');
      expectedNode = wrapAsYamlNode(null);

      /// Parsing an empty YAML document returns YamlScalar with value `null`.
      _performEdit(edit, path, expectedNode);
      return nodeToRemove;
    }

    final pathAsList = path.toList();
    final collectionPath = pathAsList.take(path.length - 1);
    final keyOrIndex = pathAsList.last;
    final parentNode = _traverse(collectionPath);

    if (parentNode is YamlList) {
      edit = removeInList(this, parentNode, keyOrIndex as int);
      expectedNode = wrapAsYamlNode(
        [...parentNode.nodes]..removeAt(keyOrIndex),
      );
    } else if (parentNode is YamlMap) {
      edit = removeInMap(this, parentNode, keyOrIndex);

      expectedNode =
          updatedYamlMap(parentNode, (nodes) => nodes.remove(keyOrIndex));
    }

    _performEdit(edit, collectionPath, expectedNode);

    return nodeToRemove;
  }

  /// Traverses down [path] to return the [YamlNode] at [path] if successful.
  ///
  /// If no [YamlNode]s exist at [path], the result of invoking the [orElse]
  /// function is returned.
  ///
  /// If [orElse] is omitted, it defaults to throwing a [PathError].
  ///
  /// If [checkAlias] is `true`, throw [AliasException] if an aliased node is
  /// encountered.
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

    // Frame-condition assertion:
    // Bytes outside the edited span must be unchanged, and comments outside
    // the modified subtree must be strictly preserved.
    _assertFrameCondition(
      initialYaml,
      updatedYaml,
      edit,
      path,
      expectedNode,
      actualTree,
    );

    // Update state of YamlEditor, when we've validated that the edit was
    // semantically correct!
    _yaml = updatedYaml;
    _contents = actualTree;
    _edits.add(edit);
    _initialize(); // update tracking of aliases
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
    RangeError.checkValueInInterval(subPath.length, 0, path.length);

    if (path.length == subPath.length) return expectedNode;

    final keyOrIndex = path.elementAt(subPath.length);

    if (tree is YamlList) {
      if (!isValidIndex(keyOrIndex, tree.length)) {
        throw PathError(path, subPath, tree);
      }

      return wrapAsYamlNode([...tree.nodes]..[keyOrIndex as int] = _deepModify(
          tree.nodes[keyOrIndex],
          path,
          path.take(subPath.length + 1),
          expectedNode));
    }

    if (tree is YamlMap) {
      return updatedYamlMap(
          tree,
          (nodes) => nodes[keyOrIndex] = _deepModify(
              nodes[keyOrIndex] as YamlNode,
              path,
              path.take(subPath.length + 1),
              expectedNode));
    }

    /// Should not ever reach here.
    throw PathError(path, subPath, tree);
  }

  /// Asserts the frame condition on the applied [edit]:
  /// 1. Bytes outside the edited span
  ///    `[edit.offset, edit.offset + edit.length)` must be unchanged.
  /// 2. Disjoint comments outside the modified subtree must be strictly
  ///    preserved (the comment multiset must change only as intended).
  void _assertFrameCondition(
    String initialYaml,
    String updatedYaml,
    SourceEdit edit,
    Iterable<Object?> path,
    YamlNode expectedNode,
    YamlNode actualTree,
  ) {
    // 1. Verify byte-level frame outside the edited span.
    final suffixLength = initialYaml.length - (edit.offset + edit.length);
    if (edit.offset < 0 ||
        edit.length < 0 ||
        edit.offset + edit.length > initialYaml.length ||
        updatedYaml.length !=
            edit.offset + edit.replacement.length + suffixLength ||
        !updatedYaml.startsWith(initialYaml.substring(0, edit.offset)) ||
        updatedYaml.substring(edit.offset + edit.replacement.length) !=
            initialYaml.substring(edit.offset + edit.length)) {
      throw createAssertionError(
        'Modification altered bytes outside the edited span.',
        initialYaml,
        updatedYaml,
      );
    }

    // 2. Verify comment preservation (multiset frame condition).
    final initialComments = _extractComments(initialYaml, _contents);
    if (initialComments.isEmpty) return;

    final updatedComments = _extractComments(updatedYaml, actualTree);
    final initialCounts = <String, int>{};
    for (final c in initialComments) {
      initialCounts[c.text] = (initialCounts[c.text] ?? 0) + 1;
    }
    final updatedCounts = <String, int>{};
    for (final c in updatedComments) {
      updatedCounts[c.text] = (updatedCounts[c.text] ?? 0) + 1;
    }

    final lostCommentTexts = <String>{};
    for (final entry in initialCounts.entries) {
      final updatedCount = updatedCounts[entry.key] ?? 0;
      if (updatedCount < entry.value) {
        lostCommentTexts.add(entry.key);
      }
    }

    if (lostCommentTexts.isEmpty) return;

    final isDocumentReplacement = path.isEmpty &&
        ((expectedNode is YamlScalar && expectedNode.value == null) ||
            (edit.offset == _contents.span.start.offset &&
                edit.length ==
                    getContentSensitiveEnd(_contents) -
                        _contents.span.start.offset));

    if (isDocumentReplacement) {
      // Entire document replaced or cleared.
      return;
    }

    final targetNode = path.isEmpty ? _contents : _traverse(path);

    bool Function(_YamlComment) isAllowedRemoval;

    if (targetNode is YamlList && expectedNode is YamlList) {
      if (expectedNode.length >= targetNode.length) {
        // Insertion or updating existing list item.
        int? updatedIndex;
        for (var i = 0; i < targetNode.length; i++) {
          if (!deepEquals(targetNode.nodes[i], expectedNode.nodes[i])) {
            updatedIndex = i;
            break;
          }
        }
        if (updatedIndex != null) {
          final oldItem = targetNode.nodes[updatedIndex];
          if (oldItem is YamlMap || oldItem is YamlList) {
            isAllowedRemoval = (c) =>
                c.offset >= oldItem.span.start.offset &&
                c.end <= oldItem.span.end.offset;
          } else {
            isAllowedRemoval = (_) => false;
          }
        } else {
          isAllowedRemoval = (_) => false;
        }
      } else {
        // List item removal.
        var removedIndex = targetNode.length - 1;
        for (var i = 0; i < expectedNode.length; i++) {
          if (!deepEquals(targetNode.nodes[i], expectedNode.nodes[i])) {
            removedIndex = i;
            break;
          }
        }
        final removedItem = targetNode.nodes[removedIndex];
        final itemLineStart =
            initialYaml.lastIndexOf('\n', removedItem.span.start.offset) + 1;
        var itemLineEnd =
            initialYaml.indexOf('\n', removedItem.span.end.offset);
        if (itemLineEnd == -1) itemLineEnd = initialYaml.length;

        isAllowedRemoval = (c) {
          // Inside the removed item subtree:
          if (c.offset >= removedItem.span.start.offset &&
              c.end <= removedItem.span.end.offset) {
            return true;
          }
          // On the line(s) of the removed item:
          if (c.offset >= itemLineStart && c.end <= itemLineEnd) {
            return true;
          }
          // In a flow list, leading comment before first item (after '['):
          if (targetNode.style == CollectionStyle.FLOW && removedIndex == 0) {
            if (c.offset >= targetNode.span.start.offset &&
                c.end <= removedItem.span.start.offset) {
              return true;
            }
          }
          // In a block list, trailing comments indented under the item:
          if (targetNode.style == CollectionStyle.BLOCK) {
            final nextItemStart = removedIndex < targetNode.length - 1
                ? targetNode.nodes[removedIndex + 1].span.start.offset
                : initialYaml.length;
            if (c.offset >= itemLineEnd && c.end <= nextItemStart) {
              final nextLineStart = nextItemStart < initialYaml.length
                  ? initialYaml.lastIndexOf('\n', nextItemStart) + 1
                  : initialYaml.length;
              if (c.end <= nextLineStart) {
                return true;
              }
            }
          }
          return false;
        };
      }
    } else if (targetNode is YamlMap && expectedNode is YamlMap) {
      if (expectedNode.length > targetNode.length) {
        // Adding new key: no comments allowed to be removed.
        isAllowedRemoval = (_) => false;
      } else if (expectedNode.length == targetNode.length) {
        // Updating an existing key.
        Object? updatedKey;
        for (final key in targetNode.keys) {
          if (!deepEquals(targetNode[key], expectedNode[key])) {
            updatedKey = key;
            break;
          }
        }
        final oldValue =
            updatedKey != null ? targetNode.nodes[updatedKey] : null;
        if (oldValue is YamlMap || oldValue is YamlList) {
          final oldCollection = oldValue as YamlNode;
          isAllowedRemoval = (c) =>
              c.offset >= oldCollection.span.start.offset &&
              c.end <= oldCollection.span.end.offset;
        } else {
          isAllowedRemoval = (_) => false;
        }
      } else {
        // Map entry removal.
        final removedKey =
            targetNode.keys.firstWhere((k) => !expectedNode.containsKey(k));
        final (index: entryIndex, :keyNode, :valueNode) =
            getYamlMapEntry(targetNode, removedKey);
        final keyLineStart =
            initialYaml.lastIndexOf('\n', keyNode.span.start.offset) + 1;
        var valueLineEnd = initialYaml.indexOf('\n', valueNode.span.end.offset);
        if (valueLineEnd == -1) valueLineEnd = initialYaml.length;

        isAllowedRemoval = (c) {
          // Inside the value node subtree:
          if (c.offset >= valueNode.span.start.offset &&
              c.end <= valueNode.span.end.offset) {
            return true;
          }
          // On the line(s) of key or value:
          if (c.offset >= keyLineStart && c.end <= valueLineEnd) {
            return true;
          }
          // In a flow map, leading comments before first key (after '{'):
          if (targetNode.style == CollectionStyle.FLOW && entryIndex == 0) {
            if (c.offset >= targetNode.span.start.offset &&
                c.end <= keyNode.span.start.offset) {
              return true;
            }
          }
          // In a block map, trailing comments indented under the entry:
          if (targetNode.style == CollectionStyle.BLOCK) {
            final nextEntryStart = entryIndex < targetNode.length - 1
                ? (targetNode.nodes.keys.elementAt(entryIndex + 1) as YamlNode)
                    .span
                    .start
                    .offset
                : initialYaml.length;
            if (c.offset >= valueLineEnd && c.end <= nextEntryStart) {
              final nextLineStart = nextEntryStart < initialYaml.length
                  ? initialYaml.lastIndexOf('\n', nextEntryStart) + 1
                  : initialYaml.length;
              if (c.end <= nextLineStart) {
                return true;
              }
            }
          }
          return false;
        };
      }
    } else {
      if (targetNode is YamlScalar) {
        isAllowedRemoval = (_) => false;
      } else {
        isAllowedRemoval = (c) =>
            c.offset >= targetNode.span.start.offset &&
            c.end <= targetNode.span.end.offset;
      }
    }

    for (final c in initialComments) {
      if (lostCommentTexts.contains(c.text)) {
        final inEditRange =
            c.end > edit.offset && c.offset < edit.offset + edit.length;
        if (inEditRange && !isAllowedRemoval(c)) {
          throw createAssertionError(
            'Frame condition violation: comment "${c.text}" was '
            'unintentionally removed.',
            initialYaml,
            updatedYaml,
          );
        }
      }
    }
  }
}

final class _YamlComment {
  final int offset;
  final int end;
  final String text;

  _YamlComment(this.offset, this.end, this.text);
}

List<_YamlComment> _extractComments(String yaml, YamlNode root) {
  final spans = <SourceSpan>[];
  final visited = <YamlNode>{};
  void collect(YamlNode node) {
    if (!visited.add(node)) return;
    if (node is YamlScalar) {
      spans.add(node.span);
    } else if (node is YamlMap) {
      for (final entry in node.nodes.entries) {
        if (entry.key is YamlNode) collect(entry.key as YamlNode);
        collect(entry.value);
      }
    } else if (node is YamlList) {
      for (final item in node.nodes) {
        collect(item);
      }
    }
  }

  collect(root);
  spans.sort((a, b) => a.start.offset.compareTo(b.start.offset));

  final comments = <_YamlComment>[];
  var i = 0;
  final len = yaml.length;
  var spanIdx = 0;

  while (i < len) {
    while (spanIdx < spans.length && spans[spanIdx].end.offset <= i) {
      spanIdx++;
    }
    if (spanIdx < spans.length &&
        spans[spanIdx].start.offset <= i &&
        i < spans[spanIdx].end.offset) {
      i = spans[spanIdx].end.offset;
      continue;
    }

    if (yaml[i] == '#') {
      final prev = i > 0 ? yaml[i - 1] : '\n';
      if (i == 0 ||
          prev == ' ' ||
          prev == '\t' ||
          prev == '\n' ||
          prev == '\r') {
        final start = i;
        while (i < len && yaml[i] != '\n' && yaml[i] != '\r') {
          i++;
        }
        final text = yaml.substring(start, i).trimRight();
        comments.add(_YamlComment(start, i, text));
      } else {
        i++;
      }
    } else {
      i++;
    }
  }

  return comments;
}
