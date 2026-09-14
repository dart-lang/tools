// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'cst.dart';
import 'cst_mutations.dart';
import 'equality.dart';
import 'errors.dart';
import 'source_edit.dart';

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
  String get _yaml => _document.source;

  /// The concrete syntax tree of the current document.
  ///
  /// This is what every modification works from. It records where each piece of
  /// syntax is written, under an invariant — checked whenever it is built —
  /// that its slots tile the source exactly. Modifications therefore never have
  /// to search the source for a delimiter, and an edit expressed against one of
  /// its slots cannot disturb anything outside that slot.
  CstDocument _document;

  /// Root node of YAML AST.
  YamlNode get _contents => _document.value;

  /// The nodes of [_contents] that are the target of an alias.
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
  Set<YamlNode> get _aliases => _document.aliasedValues;

  /// Returns the current YAML string.
  @override
  String toString() => _yaml;

  factory YamlEditor(String yaml) => YamlEditor._(yaml);

  YamlEditor._(String yaml) : _document = CstDocument.parse(yaml);

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
    final pathAsList = path.toList();

    if (pathAsList.isEmpty) {
      if (_aliases.contains(_contents)) {
        throw AliasException(pathAsList, _contents);
      }
      return _performEdit(
          buildUpdate(_document, pathAsList, valueNode), pathAsList, valueNode);
    }

    final collectionPath = pathAsList.take(pathAsList.length - 1).toList();
    final keyOrIndex = pathAsList.last;
    final parentNode = _traverse(collectionPath, checkAlias: true);
    _traverse(pathAsList, checkAlias: true, orElse: () => wrapAsYamlNode(null));

    if (parentNode is YamlList) {
      if (keyOrIndex is! int) {
        throw PathError(path, path, parentNode);
      }
      final expected = wrapAsYamlNode(
        [...parentNode.nodes]..[keyOrIndex] = valueNode,
      );
      return _performEdit(buildUpdate(_document, pathAsList, valueNode),
          collectionPath, expected);
    }

    if (parentNode is YamlMap) {
      final expectedMap =
          updatedYamlMap(parentNode, (nodes) => nodes[keyOrIndex] = valueNode);
      return _performEdit(buildUpdate(_document, pathAsList, valueNode),
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
    final pathAsList = path.toList();

    final list = _traverseToList(pathAsList, checkAlias: true);
    RangeError.checkValueInInterval(index, 0, list.length);

    final expected = wrapAsYamlNode(
      [...list.nodes]..insert(index, valueNode),
    );

    _performEdit(buildInsert(_document, pathAsList, index, valueNode),
        pathAsList, expected);
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
    final pathAsList = path.toList();
    final nodeToRemove = _traverse(pathAsList, checkAlias: true);

    if (pathAsList.isEmpty) {
      // Parsing an empty YAML document returns a YamlScalar with value `null`.
      _performEdit(
          buildRemove(_document, pathAsList), pathAsList, wrapAsYamlNode(null));
      return nodeToRemove;
    }

    final collectionPath = pathAsList.take(pathAsList.length - 1).toList();
    final keyOrIndex = pathAsList.last;
    final parentNode = _traverse(collectionPath);

    final YamlNode expectedNode;
    if (parentNode is YamlList) {
      expectedNode = wrapAsYamlNode(
        [...parentNode.nodes]..removeAt(keyOrIndex as int),
      );
    } else if (parentNode is YamlMap) {
      expectedNode =
          updatedYamlMap(parentNode, (nodes) => nodes.remove(keyOrIndex));
    } else {
      throw PathError.unexpected(
          path, 'Scalar $parentNode does not have key $keyOrIndex');
    }

    _performEdit(
        buildRemove(_document, pathAsList), collectionPath, expectedNode);

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

    // Check that the edit does actually parse, and that the result is a
    // document we can go on to model. Rebuilding the CST re-checks its tiling
    // invariant, so an edit that produced something we could not edit again is
    // rejected here rather than at the next call.
    final CstDocument updated;
    try {
      updated = withYamlWarningCallback(() => CstDocument.parse(updatedYaml));
    } on YamlException {
      throw createAssertionError(
        'Failed to produce valid YAML after modification.',
        initialYaml,
        updatedYaml,
      );
    } on CstException {
      throw createAssertionError(
        'Modification produced YAML that cannot be modelled.',
        initialYaml,
        updatedYaml,
      );
    }

    // Check that the edit is semantically correct
    if (!deepEquals(updated.value, expectedTree)) {
      throw createAssertionError(
        'Modification did not result in expected result.',
        initialYaml,
        updatedYaml,
      );
    }

    // Update state of YamlEditor, when we've validated that the edit was
    // semantically correct!
    _document = updated;
    _edits.add(edit);
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
}
