// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Grammar-guided seeded fuzzing for `package:yaml_edit`.
///
/// Generates YAML documents with tagged comments, variable indentation
/// (1–4 spaces), block and flow collections, explicit keys, empty collections,
/// zero-indent sequences, block scalars, multiline plain scalars, blank lines,
/// directives/`---`/`...`, anchors with referenced `*alias`es, and LF/CRLF line
/// endings, then exercises:
/// - CST parsing and token stream non-overlap;
/// - independent plain-string tag-based comment preservation;
/// - `SourceEdit.applyAll(initial, editor.edits) == editor.toString()` replay;
/// - stateful 12-step mutation trajectories across all `YamlEditor` operations;
/// - round-trip updates, insert/remove cancellation, and disjoint commutativity.
library;

import 'dart:math' show Random;

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Extracts all comment texts from [yaml] via [loadYamlDocumentWithTokens] and
/// checks token stream ordering and non-overlap.
List<String> _extractComments(String yaml) {
  final (:tokens, document: _) = loadYamlDocumentWithTokens(yaml);
  for (var index = 0; index < tokens.length; index++) {
    expect(tokens[index].span.length, greaterThan(0),
        reason: 'Token must have positive length');
    if (index > 0) {
      expect(
        tokens[index].span.start.offset,
        greaterThanOrEqualTo(tokens[index - 1].span.start.offset),
        reason: 'Tokens must be sorted by start offset',
      );
      if (tokens[index].span.start.offset < tokens[index - 1].span.end.offset) {
        // The only token allowed inside another token's span is a header
        // comment inside a block scalar.
        expect(tokens[index].kind, equals(YamlTokenKind.comment),
            reason: 'Only comments may be nested inside another token span');
        expect(tokens[index - 1].kind, equals(YamlTokenKind.scalar),
            reason: 'Only scalars may contain a header comment');
      }
    }
  }
  return [
    for (final token in tokens)
      if (token.kind == YamlTokenKind.comment) token.span.text,
  ];
}

/// Independent comment oracle: verifies via plain string search (without using
/// `loadYamlDocumentWithTokens`) that every [expectedTags] appears exactly once
/// in [yaml] and in the original relative order.
void _assertTaggedCommentsInOrder(
  String yaml,
  List<String> expectedTags, {
  String? reason,
}) {
  var lastOffset = -1;
  for (final tag in expectedTags) {
    final first = yaml.indexOf(tag);
    expect(
      first,
      isNot(-1),
      reason: 'Missing comment tag $tag${reason != null ? ' ($reason)' : ''}\n'
          'YAML:\n$yaml',
    );
    expect(
      yaml.indexOf(tag, first + 1),
      equals(-1),
      reason:
          'Duplicate comment tag $tag${reason != null ? ' ($reason)' : ''}\n'
          'YAML:\n$yaml',
    );
    expect(
      first,
      greaterThan(lastOffset),
      reason:
          'Out-of-order comment tag $tag${reason != null ? ' ($reason)' : ''}\n'
          'YAML:\n$yaml',
    );
    lastOffset = first;
  }
}

/// Verifies that replaying `editor.edits` against [initialYaml] reproduces
/// `editor.toString()` byte-for-byte.
void _assertEditsReplay(String initialYaml, YamlEditor editor) {
  expect(
    SourceEdit.applyAll(initialYaml, editor.edits),
    equals(editor.toString()),
    reason: 'SourceEdit.applyAll(initial, editor.edits) diverged from '
        'editor.toString()',
  );
}

const _quotingNeededStrings = [
  '',
  ' ',
  'true',
  'false',
  'null',
  '~',
  '123',
  'a: b',
  '# not a comment',
  '- leading dash',
  '[brackets]',
  '{braces}',
  "it's quoted",
  'say "hi"',
  'line1\nline2',
  '&anchor *alias',
];

/// Grammar-guided generator producing YAML documents with tagged comments.
final class _StructuredYamlGenerator {
  final Random random;
  final String lineEnding;
  final int indentStep;
  int _commentCounter = 0;
  int _anchorCounter = 0;

  /// Every `# @kind_N` comment emitted during the most recent
  /// [generateDocument] call, in emission order.
  final List<String> emittedComments = [];

  /// Scalar anchors emitted earlier in the current document that can safely be
  /// referenced via `*anchor`.
  final List<String> _availableScalarAnchors = [];

  _StructuredYamlGenerator(
    this.random, {
    this.lineEnding = '\n',
    this.indentStep = 2,
  });

  String _nextComment(String kind) {
    final tag = '# @${kind}_${_commentCounter++}@';
    emittedComments.add(tag);
    return tag;
  }

  String _propertyPrefix({
    String? expectedType,
    bool allowScalarAnchor = false,
  }) {
    final roll = random.nextInt(10);
    if (roll == 0) {
      final name = 'a_${_anchorCounter++}';
      if (allowScalarAnchor) _availableScalarAnchors.add(name);
      return '&$name ';
    } else if (roll == 1) {
      if (expectedType == 'str') {
        return '!!str ';
      } else if (expectedType == 'int') {
        return '!!int ';
      } else if (expectedType == 'bool') {
        return '!!bool ';
      } else if (expectedType == 'map') {
        return '!!map ';
      } else if (expectedType == 'seq') {
        return '!!seq ';
      }
      return '';
    }
    return '';
  }

  /// Generates a rich YAML document with tagged comments and diverse styles.
  ///
  /// When [includeAliases] is `true`, previously defined scalar anchors may be
  /// referenced via `*alias` (which means mutations touching the anchor itself
  /// may throw [AliasException]).
  String generateDocument({
    int maxDepth = 3,
    bool includeAliases = false,
    bool allowFlowOrScalarRoot = false,
  }) {
    _commentCounter = 0;
    _anchorCounter = 0;
    emittedComments.clear();
    _availableScalarAnchors.clear();

    final buffer = StringBuffer();
    // Optional directive and document start marker.
    final hasDirective = random.nextInt(5) == 0;
    if (hasDirective) {
      buffer.write('%YAML 1.2$lineEnding');
    }
    // Leading comment before root.
    if (random.nextBool()) {
      buffer.write('${_nextComment('header')}$lineEnding');
    }
    if (hasDirective || random.nextInt(4) == 0) {
      buffer.write('---$lineEnding');
    }

    final rootRoll =
        allowFlowOrScalarRoot ? random.nextInt(6) : random.nextInt(2);
    switch (rootRoll) {
      case 0 || 2 || 3:
        buffer.write(
          _generateBlockMap(0, maxDepth, includeAliases: includeAliases),
        );
      case 1:
        buffer.write(
          _generateBlockSeq(0, maxDepth, includeAliases: includeAliases),
        );
      case 4:
        buffer.write(_generateFlowCollection(0));
      default:
        buffer.write(_generateScalar(0, includeAliases: false));
    }
    buffer.write(lineEnding);

    // Optional explicit document end marker.
    if (random.nextInt(5) == 0) {
      buffer.write('...$lineEnding');
    }
    // Trailing comment at EOF.
    if (random.nextBool()) {
      buffer.write('${_nextComment('footer')}$lineEnding');
    }
    return buffer.toString();
  }

  String _generateBlockMap(
    int indent,
    int depth, {
    required bool includeAliases,
  }) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    final childIndent = indent + indentStep;
    for (var index = 0; index < count; index++) {
      if (index > 0 && random.nextInt(4) == 0) {
        lines.add('');
      }
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_map_k_${depth}_$index')}');
      }

      final key = 'k_${depth}_$index';
      final kind = depth > 0 ? random.nextInt(10) : random.nextInt(5);
      if (kind == 0 || depth <= 0) {
        final isExplicit = random.nextInt(4) == 0;
        final isEmptyValue = !isExplicit && random.nextInt(5) == 0;
        if (isEmptyValue) {
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('empty_map_$key')}' : '';
          lines.add('$prefix$key:$trailingComment');
        } else if (isExplicit) {
          final hasValue = random.nextBool();
          if (hasValue) {
            final afterQuestion =
                random.nextBool() ? ' ${_nextComment('after_q_$key')}' : '';
            final afterKey =
                random.nextBool() ? ' ${_nextComment('after_k_$key')}' : '';
            final scalar =
                _generateScalar(childIndent, includeAliases: includeAliases);
            if (afterQuestion.isNotEmpty) {
              lines.add(
                '$prefix?$afterQuestion$lineEnding'
                '$prefix${' ' * indentStep}$key$afterKey$lineEnding'
                '$prefix: $scalar',
              );
            } else {
              lines.add(
                '$prefix? $key$afterKey$lineEnding'
                '$prefix: $scalar',
              );
            }
          } else {
            final trailingComment =
                random.nextBool() ? ' ${_nextComment('trail_q_$key')}' : '';
            lines.add('$prefix? $key$trailingComment');
          }
        } else if (kind == 4 && random.nextBool()) {
          final trailingComment = random.nextBool()
              ? ' ${_nextComment('multiline_plain_$key')}'
              : '';
          lines.add(
            '$prefix$key: plain_first_${random.nextInt(50)}$lineEnding'
            '${' ' * childIndent}plain_second_${random.nextInt(50)}'
            '$trailingComment',
          );
        } else {
          final scalar =
              _generateScalar(indent, includeAliases: includeAliases);
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
          lines.add('$prefix$key: $scalar$trailingComment');
        }
      } else if (kind == 1) {
        final blockScalar = _generateBlockScalar(childIndent, 'trail_map_$key');
        lines.add('$prefix$key: $blockScalar');
      } else if (kind == 2) {
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        lines.add('$prefix$key:$trailingComment');
        lines.add(
          _generateBlockMap(childIndent, depth - 1,
              includeAliases: includeAliases),
        );
      } else if (kind == 3) {
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('colon_seq_$key')}' : '';
        lines.add('$prefix$key:$trailingComment');
        lines.add(
          _generateBlockSeq(childIndent, depth - 1,
              includeAliases: includeAliases),
        );
      } else if (kind == 4) {
        final flow = _generateFlowCollection(childIndent);
        lines.add('$prefix$key: $flow');
      } else if (kind == 5) {
        // Zero-indent block sequence directly under a mapping key.
        lines.add('$prefix$key:');
        lines.add('$prefix- zero_indent_0$lineEnding$prefix- zero_indent_1');
      } else if (kind == 6) {
        // Empty flow collection (`[]` or `{}`).
        final emptyFlow = random.nextBool() ? '[]' : '{}';
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('empty_flow_$key')}' : '';
        lines.add('$prefix$key: $emptyFlow$trailingComment');
      } else if (kind == 7) {
        // Explicit ? key with nested block map value.
        lines.add('$prefix? exp_key_${depth}_$index$lineEnding$prefix:');
        lines.add(
          _generateBlockMap(childIndent, depth - 1,
              includeAliases: includeAliases),
        );
      } else if (kind == 8) {
        // Multiline plain scalar value at any nesting depth.
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('multiline_plain_$key')}' : '';
        lines.add(
          '$prefix$key: plain_first_${random.nextInt(50)}$lineEnding'
          '${' ' * childIndent}plain_second_${random.nextInt(50)}'
          '$trailingComment',
        );
      } else {
        // Indented compact block sequence under key.
        lines.add('$prefix$key:');
        lines.add(
          '${' ' * childIndent}- compact_item_0$lineEnding'
          '${' ' * childIndent}- compact_item_1',
        );
      }
    }
    return lines.join(lineEnding);
  }

  String _generateBlockSeq(
    int indent,
    int depth, {
    required bool includeAliases,
  }) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    final childIndent = indent + indentStep;
    for (var index = 0; index < count; index++) {
      if (index > 0 && random.nextInt(4) == 0) {
        lines.add('');
      }
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_seq_$index')}');
      }

      final kind = depth > 0 ? random.nextInt(6) : random.nextInt(3);
      if (kind == 0) {
        final isNextLine = random.nextInt(4) == 0;
        final isEmptyItem = !isNextLine && random.nextInt(4) == 0;
        if (isEmptyItem) {
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('empty_seq_$index')}' : '';
          lines.add('$prefix-$trailingComment');
        } else if (isNextLine) {
          final afterDashComment =
              random.nextBool() ? ' ${_nextComment('after_dash_$index')}' : '';
          final scalar =
              _generateScalar(childIndent, includeAliases: includeAliases);
          lines.add(
            '$prefix-$afterDashComment$lineEnding${' ' * childIndent}$scalar',
          );
        } else {
          final scalar =
              _generateScalar(indent, includeAliases: includeAliases);
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('trail_seq_$index')}' : '';
          lines.add('$prefix- $scalar$trailingComment');
        }
      } else if (kind == 1) {
        final blockScalar =
            _generateBlockScalar(childIndent, 'trail_seq_$index');
        lines.add('$prefix- $blockScalar');
      } else if (kind == 2) {
        lines.add('$prefix- ${_generateFlowCollection(childIndent)}');
      } else if (kind == 3) {
        // Compact block map inside sequence (keys align at indent + 2).
        final key1 = 'ck_${depth}_0';
        final key2 = 'ck_${depth}_1';
        lines.add(
          '$prefix- $key1: '
          '${_generateScalar(indent + 2, includeAliases: includeAliases)}',
        );
        lines.add(
          '$prefix  $key2: '
          '${_generateScalar(indent + 2, includeAliases: includeAliases)}',
        );
      } else if (kind == 4) {
        // Compact nested block sequence inside sequence (- - a\n  - b).
        lines.add('$prefix- - nested_seq_a');
        lines.add('$prefix  - nested_seq_b');
      } else {
        // Empty flow collection item.
        lines.add('$prefix- ${random.nextBool() ? '[]' : '{}'}');
      }
    }
    return lines.join(lineEnding);
  }

  String _generateFlowCollection(int indent) {
    final isMap = random.nextBool();
    final isMultiline = random.nextBool();
    final count = 2 + random.nextInt(3);
    final property = _propertyPrefix(expectedType: isMap ? 'map' : 'seq');

    if (!isMap) {
      if (!isMultiline) {
        final hasFlowPair = random.nextBool();
        final items = <String>[];
        for (var index = 0; index < count; index++) {
          if (hasFlowPair && index == 0) {
            final isExplicitPair = random.nextBool();
            items.add(isExplicitPair
                ? '? fp_k: ${_generateSimpleScalar()}'
                : 'fp_k: ${_generateSimpleScalar()}');
          } else {
            items.add(_generateSimpleScalar());
          }
        }
        final trailingComma = random.nextInt(4) == 0 ? ',' : '';
        return '$property[${items.join(', ')}$trailingComma]';
      }

      final prefix = ' ' * indent;
      final itemPrefix = ' ' * (indent + indentStep);
      final buffer = StringBuffer('$property[$lineEnding');
      for (var index = 0; index < count; index++) {
        if (random.nextBool()) {
          buffer.write(
              '$itemPrefix${_nextComment('lead_flowseq_$index')}$lineEnding');
        }
        final item = (index == 0 && random.nextBool())
            ? 'pair_k: ${_generateSimpleScalar()}'
            : _generateSimpleScalar();

        if (index < count - 1) {
          if (random.nextBool()) {
            buffer.write(
              '$itemPrefix$item ${_nextComment('before_comma_$index')}'
              '$lineEnding$itemPrefix,$lineEnding',
            );
          } else {
            final afterComma = random.nextBool()
                ? ' ${_nextComment('after_comma_$index')}'
                : '';
            buffer.write('$itemPrefix$item,$afterComma$lineEnding');
          }
        } else {
          final trailingComma = random.nextBool() ? ',' : '';
          final trailingComment = random.nextBool()
              ? ' ${_nextComment('trail_flowseq_$index')}'
              : '';
          buffer.write(
              '$itemPrefix$item$trailingComma$trailingComment$lineEnding');
        }
      }
      if (random.nextBool()) {
        buffer
            .write('$itemPrefix${_nextComment('before_close_seq')}$lineEnding');
      }
      buffer.write('$prefix]');
      return buffer.toString();
    } else {
      if (!isMultiline) {
        final items = List.generate(count, (index) {
          if (index == 0 && random.nextInt(4) == 0) {
            return 'fk_$index: ';
          }
          final isExplicit = random.nextInt(4) == 0;
          return isExplicit
              ? '? fk_$index: ${_generateSimpleScalar()}'
              : 'fk_$index: ${_generateSimpleScalar()}';
        });
        final trailingComma = random.nextInt(4) == 0 ? ',' : '';
        return '$property{${items.join(', ')}$trailingComma}';
      }

      final prefix = ' ' * indent;
      final itemPrefix = ' ' * (indent + indentStep);
      final buffer = StringBuffer('$property{$lineEnding');
      for (var index = 0; index < count; index++) {
        if (random.nextBool()) {
          buffer.write(
              '$itemPrefix${_nextComment('lead_flowmap_$index')}$lineEnding');
        }
        final isEmptyValue = index == 0 && random.nextInt(4) == 0;
        final pair = isEmptyValue
            ? 'fk_$index: '
            : 'fk_$index: ${_generateSimpleScalar()}';

        if (index < count - 1) {
          if (!isEmptyValue && random.nextBool()) {
            buffer.write(
              '$itemPrefix$pair ${_nextComment('before_comma_m_$index')}'
              '$lineEnding$itemPrefix,$lineEnding',
            );
          } else {
            final afterComma = random.nextBool()
                ? ' ${_nextComment('after_comma_m_$index')}'
                : '';
            buffer.write('$itemPrefix$pair,$afterComma$lineEnding');
          }
        } else {
          final trailingComma = random.nextBool() ? ',' : '';
          final trailingComment = random.nextBool()
              ? ' ${_nextComment('trail_flowmap_$index')}'
              : '';
          buffer.write(
              '$itemPrefix$pair$trailingComma$trailingComment$lineEnding');
        }
      }
      if (random.nextBool()) {
        buffer
            .write('$itemPrefix${_nextComment('before_close_map')}$lineEnding');
      }
      buffer.write('$prefix}');
      return buffer.toString();
    }
  }

  String _generateBlockScalar(int bodyIndent, String fallbackKind) {
    final style = random.nextBool() ? '|' : '>';
    final chomp = ['', '-', '+'][random.nextInt(3)];
    final indentIndicator = random.nextBool() ? '2' : '';
    final headerComment = random.nextBool()
        ? ' ${_nextComment('scalar_header')}'
        : (random.nextBool() ? ' ${_nextComment(fallbackKind)}' : '');
    final prefix = ' ' * (bodyIndent + (indentIndicator.isNotEmpty ? 2 : 0));
    final extraKeepLines = chomp == '+' ? '$lineEnding$prefix$lineEnding' : '';
    return '$style$chomp$indentIndicator$headerComment$lineEnding'
        '${prefix}line_one_${random.nextInt(100)}$lineEnding'
        '${prefix}line_two_${random.nextInt(100)}$extraKeepLines';
  }

  String _generateScalar(int indent, {required bool includeAliases}) {
    if (includeAliases &&
        _availableScalarAnchors.isNotEmpty &&
        random.nextInt(4) == 0) {
      final anchor = _availableScalarAnchors[
          random.nextInt(_availableScalarAnchors.length)];
      return '*$anchor';
    }
    switch (random.nextInt(5)) {
      case 0:
        final prefix =
            _propertyPrefix(expectedType: 'int', allowScalarAnchor: true);
        return '$prefix${random.nextInt(1000)}';
      case 1:
        final prefix =
            _propertyPrefix(expectedType: 'bool', allowScalarAnchor: true);
        return '$prefix${random.nextBool() ? 'true' : 'false'}';
      case 2:
        final prefix =
            _propertyPrefix(expectedType: 'str', allowScalarAnchor: true);
        return '${prefix}plain_${random.nextInt(100)}';
      case 3:
        final propertyPrefix =
            _propertyPrefix(expectedType: 'str', allowScalarAnchor: true);
        return "$propertyPrefix'single_${random.nextInt(100)}'";
      default:
        final propertyPrefix =
            _propertyPrefix(expectedType: 'str', allowScalarAnchor: true);
        return '$propertyPrefix"double_${random.nextInt(100)}"';
    }
  }

  String _generateSimpleScalar() {
    switch (random.nextInt(3)) {
      case 0:
        final prefix =
            _propertyPrefix(expectedType: 'int', allowScalarAnchor: true);
        return '$prefix${random.nextInt(100)}';
      case 1:
        final propertyPrefix =
            _propertyPrefix(expectedType: 'str', allowScalarAnchor: true);
        return "$propertyPrefix's_${random.nextInt(100)}'";
      default:
        final propertyPrefix =
            _propertyPrefix(expectedType: 'str', allowScalarAnchor: true);
        return '$propertyPrefix"d_${random.nextInt(100)}"';
    }
  }

  Object? generateRandomValue({int depth = 0, bool allowCollections = true}) {
    final maxChoice = allowCollections && depth < 2 ? 11 : 7;
    switch (random.nextInt(maxChoice)) {
      case 0:
        return null;
      case 1:
        return random.nextBool();
      case 2:
        return random.nextInt(10000);
      case 3:
        return 'str_${random.nextInt(1000)}';
      case 4:
        return _quotingNeededStrings[
            random.nextInt(_quotingNeededStrings.length)];
      case 5:
        return YamlScalar.wrap(
          'block_line_1\nblock_line_2',
          style: random.nextBool() ? ScalarStyle.LITERAL : ScalarStyle.FOLDED,
        );
      case 6:
        return YamlScalar.wrap(
          'quoted_${random.nextInt(100)}',
          style: random.nextBool()
              ? ScalarStyle.SINGLE_QUOTED
              : ScalarStyle.DOUBLE_QUOTED,
        );
      case 7:
        return random.nextBool() ? <Object?>[] : <String, Object?>{};
      case 8:
        return wrapAsYamlNode(
          [
            generateRandomValue(depth: depth + 1, allowCollections: false),
            random.nextInt(50),
          ],
          collectionStyle:
              random.nextBool() ? CollectionStyle.FLOW : CollectionStyle.BLOCK,
        );
      case 9:
        return wrapAsYamlNode(
          {
            'nested_k':
                generateRandomValue(depth: depth + 1, allowCollections: false),
            'nested_n': random.nextInt(50),
          },
          collectionStyle:
              random.nextBool() ? CollectionStyle.FLOW : CollectionStyle.BLOCK,
        );
      default:
        // Nested block collection holding another block collection.
        return {
          'outer': [
            'deep_${random.nextInt(20)}',
            {'leaf': random.nextInt(20)},
          ],
        };
    }
  }
}

/// Collects all paths in [editor] pointing to scalar values, lists, or maps.
List<List<Object?>> _collectPaths(YamlEditor editor) {
  final paths = <List<Object?>>[];
  void walk(YamlNode node, List<Object?> current) {
    paths.add(current);
    if (node is YamlMap) {
      for (final key in node.keys) {
        if (node.nodes[key] case final childNode?) {
          walk(childNode, [...current, key]);
        }
      }
    } else if (node is YamlList) {
      for (var index = 0; index < node.length; index++) {
        walk(node.nodes[index], [...current, index]);
      }
    }
  }

  walk(editor.parseAt([]), []);
  return paths;
}

/// Checks whether two paths are structurally disjoint (neither is a prefix of
/// the other).
bool _areDisjointUpdatePaths(List<Object?> path1, List<Object?> path2) {
  if (path1.isEmpty || path2.isEmpty) return false;
  final minLength = path1.length < path2.length ? path1.length : path2.length;
  for (var index = 0; index < minLength; index++) {
    if (path1[index] != path2[index]) return true;
  }
  return false;
}

void main() {
  const indentSteps = [1, 2, 3, 4];

  group('CST parsing and token stream integrity', () {
    test('generated documents parse cleanly before and after updates', () {
      for (var round = 0; round < 60; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(1001 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(
          maxDepth: 2,
          allowFlowOrScalarRoot: true,
        );
        CstDocument.parse(yaml);
        _extractComments(yaml);
        _assertTaggedCommentsInOrder(yaml, generator.emittedComments);

        final editor = YamlEditor(yaml);
        final paths = _collectPaths(editor);
        final path = paths[generator.random.nextInt(paths.length)];
        final newValue = generator.generateRandomValue();

        editor.update(path, newValue);
        final afterYaml = editor.toString();

        CstDocument.parse(afterYaml);
        _extractComments(afterYaml);
        _assertEditsReplay(yaml, editor);
      }
    });
  });

  group('comment preservation', () {
    test('preserves all comments across repeated scalar updates', () {
      for (var round = 0; round < 50; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(2002 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);
        final emittedTags = List<String>.of(generator.emittedComments);

        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where(
                (path) => path.isNotEmpty && editor.parseAt(path) is YamlScalar)
            .toList();
        if (scalarPaths.isEmpty) continue;

        for (var step = 0; step < 3; step++) {
          final path =
              scalarPaths[generator.random.nextInt(scalarPaths.length)];
          final newValue = generator.generateRandomValue();
          editor.update(path, newValue);

          final after = editor.toString();
          expect(
            _extractComments(after),
            equals(initialComments),
            reason: 'Update of scalar path $path to $newValue lost or '
                'reordered comments on round $round step $step!\n'
                'Before:\n$yaml\nAfter:\n$after',
          );
          _assertTaggedCommentsInOrder(
            after,
            emittedTags,
            reason: 'round $round step $step',
          );
          _assertEditsReplay(yaml, editor);
        }
      }
    });

    test(
        'preserves all comments across insert, prepend, append, and map key '
        'additions', () {
      for (var round = 0; round < 40; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(2003 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);
        final emittedTags = List<String>.of(generator.emittedComments);

        final editor = YamlEditor(yaml);
        final paths = _collectPaths(editor);
        for (final path in paths) {
          final node = editor.parseAt(path);
          if (node is YamlList) {
            final op = round % 3;
            final val = generator.generateRandomValue(allowCollections: false);
            if (op == 0) {
              editor.prependToList(path, val);
            } else if (op == 1) {
              editor.appendToList(path, val);
            } else {
              final index = generator.random.nextInt(node.length + 1);
              editor.insertIntoList(path, index, val);
            }
            expect(
              _extractComments(editor.toString()),
              equals(initialComments),
              reason: 'List insertion op=$op lost comments',
            );
            _assertTaggedCommentsInOrder(editor.toString(), emittedTags);
            _assertEditsReplay(yaml, editor);
            break;
          } else if (node is YamlMap) {
            editor.update(
              [...path, 'new_key_$round'],
              generator.generateRandomValue(allowCollections: false),
            );
            expect(
              _extractComments(editor.toString()),
              equals(initialComments),
              reason: 'Adding map key lost comments',
            );
            _assertTaggedCommentsInOrder(editor.toString(), emittedTags);
            _assertEditsReplay(yaml, editor);
            break;
          }
        }
      }
    });

    test('flow collection removal preserves leading and sibling comments', () {
      const flowWithComments = '''
items: [
  # lead 0
  10, # trail 0
  # lead 1
  20, # trail 1
  # lead 2
  30 # trail 2
  # before close
]
''';
      final editor0 = YamlEditor(flowWithComments)..remove(['items', 0]);
      expect(
        _extractComments(editor0.toString()),
        equals([
          '# lead 0',
          '# lead 1',
          '# trail 1',
          '# lead 2',
          '# trail 2',
          '# before close',
        ]),
      );
      _assertEditsReplay(flowWithComments, editor0);

      final editor1 = YamlEditor(flowWithComments)..remove(['items', 1]);
      expect(
        _extractComments(editor1.toString()),
        equals([
          '# lead 0',
          '# trail 0',
          '# lead 1',
          '# lead 2',
          '# trail 2',
          '# before close',
        ]),
      );
      _assertEditsReplay(flowWithComments, editor1);

      final editor2 = YamlEditor(flowWithComments)..remove(['items', 2]);
      expect(
        _extractComments(editor2.toString()),
        equals([
          '# lead 0',
          '# trail 0',
          '# lead 1',
          '# trail 1',
          '# lead 2',
          '# before close',
        ]),
      );
      _assertEditsReplay(flowWithComments, editor2);
    });

    test('fuzzed removal of every path preserves non-entry comments', () {
      var totalRemovals = 0;
      for (var round = 0; round < 35; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(2004 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final baseEditor = YamlEditor(yaml);
        final paths =
            _collectPaths(baseEditor).where((path) => path.isNotEmpty).toList();

        for (final path in paths) {
          totalRemovals++;
          final editor = YamlEditor(yaml);
          editor.remove(path);
          _extractComments(editor.toString());
          _assertEditsReplay(yaml, editor);
        }
      }
      expect(totalRemovals, greaterThan(300));
    });
  });

  group('stateful multi-step trajectories', () {
    test(
        'survives 12-step mixed trajectories with aliases, splice, prepend, '
        'append, remove, and root edits', () {
      var totalOps = 0;
      var aliasExceptions = 0;
      var spliceOps = 0;
      var rootEdits = 0;

      for (var round = 0; round < 50; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(6006 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final initialYaml = generator.generateDocument(
          maxDepth: 2,
          includeAliases: true,
          allowFlowOrScalarRoot: round % 5 == 0,
        );
        final editor = YamlEditor(initialYaml);
        final random = generator.random;

        for (var step = 0; step < 12; step++) {
          final paths = _collectPaths(editor);
          final path = paths[random.nextInt(paths.length)];
          final node = editor.parseAt(path);

          try {
            if (path.isEmpty && random.nextInt(5) == 0) {
              rootEdits++;
              editor.update([], generator.generateRandomValue());
            } else if (node is YamlList) {
              switch (random.nextInt(6)) {
                case 0:
                  editor.prependToList(
                    path,
                    generator.generateRandomValue(allowCollections: false),
                  );
                case 1:
                  editor.appendToList(
                    path,
                    generator.generateRandomValue(allowCollections: false),
                  );
                case 2:
                  final idx = random.nextInt(node.length + 1);
                  editor.insertIntoList(
                    path,
                    idx,
                    generator.generateRandomValue(allowCollections: false),
                  );
                case 3:
                  spliceOps++;
                  final idx = random.nextInt(node.length + 1);
                  final deleteCount = random.nextInt(node.length - idx + 1);
                  final replacementCount = random.nextInt(3);
                  editor.spliceList(
                    path,
                    idx,
                    deleteCount,
                    [
                      for (var i = 0; i < replacementCount; i++)
                        generator.generateRandomValue(allowCollections: false),
                    ],
                  );
                case 4:
                  if (node.isNotEmpty) {
                    final idx = random.nextInt(node.length);
                    editor.update(
                      [...path, idx],
                      generator.generateRandomValue(),
                    );
                  }
                default:
                  if (path.isNotEmpty) {
                    editor.remove(path);
                  } else if (node.isNotEmpty) {
                    editor.remove([random.nextInt(node.length)]);
                  }
              }
            } else if (node is YamlMap) {
              switch (random.nextInt(3)) {
                case 0:
                  editor.update(
                    [...path, 'added_${round}_$step'],
                    generator.generateRandomValue(),
                  );
                case 1:
                  if (node.isNotEmpty) {
                    final keys = node.keys.toList();
                    final key = keys[random.nextInt(keys.length)];
                    editor.update(
                      [...path, key],
                      generator.generateRandomValue(),
                    );
                  }
                default:
                  if (node.isNotEmpty) {
                    final keys = node.keys.toList();
                    final key = keys[random.nextInt(keys.length)];
                    editor.remove([...path, key]);
                  } else if (path.isNotEmpty) {
                    editor.remove(path);
                  }
              }
            } else {
              if (path.isNotEmpty && random.nextBool()) {
                editor.remove(path);
              } else {
                editor.update(path, generator.generateRandomValue());
              }
            }
            totalOps++;
          } on AliasException {
            aliasExceptions++;
          }

          final current = editor.toString();
          CstDocument.parse(current);
          _extractComments(current);
          _assertEditsReplay(initialYaml, editor);
        }
      }

      expect(totalOps, greaterThan(400));
      expect(aliasExceptions, greaterThan(0),
          reason: 'Expected referenced aliases to exercise AliasException');
      expect(spliceOps, greaterThan(10));
      expect(rootEdits, greaterThan(0));
    });
  });

  group('update round-trips, cancellation, and commutativity', () {
    test(
        'plain scalar self-update is byte-identical and block round-trip '
        'preserves semantics and comments', () {
      for (var round = 0; round < 40; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(3003 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final emittedTags = List<String>.of(generator.emittedComments);
        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where(
                (path) => path.isNotEmpty && editor.parseAt(path) is YamlScalar)
            .toList();
        if (scalarPaths.isEmpty) continue;

        final path = scalarPaths[generator.random.nextInt(scalarPaths.length)];
        final originalNode = editor.parseAt(path) as YamlScalar;

        if (originalNode.style == ScalarStyle.PLAIN) {
          final selfEditor = YamlEditor(yaml)..update(path, originalNode.value);
          expect(selfEditor.toString(), equals(yaml),
              reason: 'Plain scalar self-update changed document bytes');
        }

        final blockIntermediate = YamlScalar.wrap(
          'intermediate_line_1\nintermediate_line_2',
          style: ScalarStyle.LITERAL,
        );
        final finalScalar = 'final_val_$round';

        final twoStep = YamlEditor(yaml)
          ..update(path, blockIntermediate)
          ..update(path, finalScalar);

        final oneStep = YamlEditor(yaml)..update(path, finalScalar);

        expect(
          deepEquals(twoStep.parseAt([]), oneStep.parseAt([])),
          isTrue,
          reason: 'Block-scalar round-trip semantic mismatch',
        );
        expect(
          _extractComments(twoStep.toString()),
          equals(_extractComments(oneStep.toString())),
          reason: 'Transitioning through a block scalar lost comments',
        );
        _assertTaggedCommentsInOrder(twoStep.toString(), emittedTags);
        _assertEditsReplay(yaml, twoStep);
      }
    });

    test('insert-then-remove restores semantics and comments', () {
      for (var round = 0; round < 40; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(4004 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final emittedTags = List<String>.of(generator.emittedComments);
        final editor = YamlEditor(yaml);
        final allPaths = _collectPaths(editor);
        final listPaths =
            allPaths.where((path) => editor.parseAt(path) is YamlList).toList();
        final mapPaths =
            allPaths.where((path) => editor.parseAt(path) is YamlMap).toList();

        final initialComments = _extractComments(yaml);
        final initialTree = editor.parseAt([]);

        if (listPaths.isNotEmpty) {
          final listPath =
              listPaths[generator.random.nextInt(listPaths.length)];
          final listNode = editor.parseAt(listPath) as YamlList;
          final index = generator.random.nextInt(listNode.length + 1);

          final listEditor = YamlEditor(yaml);
          listEditor.insertIntoList(listPath, index, 'temp_item_$round');
          listEditor.remove([...listPath, index]);

          expect(
            deepEquals(listEditor.parseAt([]), initialTree),
            isTrue,
            reason: 'List insert-remove failed to restore semantic tree',
          );
          expect(
            _extractComments(listEditor.toString()),
            equals(initialComments),
            reason: 'List insert-remove failed to preserve comments',
          );
          _assertTaggedCommentsInOrder(listEditor.toString(), emittedTags);
          _assertEditsReplay(yaml, listEditor);
        }

        if (mapPaths.isNotEmpty) {
          final mapPath = mapPaths[generator.random.nextInt(mapPaths.length)];
          final newKey = 'temp_k_$round';

          final mapEditor = YamlEditor(yaml);
          mapEditor.update([...mapPath, newKey], 'temp_val_$round');
          mapEditor.remove([...mapPath, newKey]);

          expect(
            deepEquals(mapEditor.parseAt([]), initialTree),
            isTrue,
            reason: 'Map insert-remove failed to restore semantic tree',
          );
          expect(
            _extractComments(mapEditor.toString()),
            equals(initialComments),
            reason: 'Map insert-remove failed to preserve comments',
          );
          _assertTaggedCommentsInOrder(mapEditor.toString(), emittedTags);
          _assertEditsReplay(yaml, mapEditor);
        }
      }
    });

    test('disjoint scalar updates commute byte-for-byte', () {
      var testedPairs = 0;
      for (var round = 0; round < 60; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(5005 + round),
          lineEnding: lineEnding,
          indentStep: indentSteps[round % indentSteps.length],
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final emittedTags = List<String>.of(generator.emittedComments);
        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where(
                (path) => path.isNotEmpty && editor.parseAt(path) is YamlScalar)
            .toList();
        if (scalarPaths.length < 2) continue;

        final disjointPairs = <(List<Object?>, List<Object?>)>[];
        for (var index1 = 0; index1 < scalarPaths.length; index1++) {
          for (var index2 = index1 + 1; index2 < scalarPaths.length; index2++) {
            if (_areDisjointUpdatePaths(
                scalarPaths[index1], scalarPaths[index2])) {
              disjointPairs.add((scalarPaths[index1], scalarPaths[index2]));
            }
          }
        }
        if (disjointPairs.isEmpty) continue;
        final (path1, path2) =
            disjointPairs[generator.random.nextInt(disjointPairs.length)];

        testedPairs++;
        final value1 = generator.generateRandomValue();
        final value2 = generator.generateRandomValue();

        final orderAB = YamlEditor(yaml)
          ..update(path1, value1)
          ..update(path2, value2);

        final orderBA = YamlEditor(yaml)
          ..update(path2, value2)
          ..update(path1, value1);

        expect(
          orderAB.toString(),
          equals(orderBA.toString()),
          reason: 'Disjoint updates at $path1 and $path2 failed to commute '
              'byte-for-byte on document:\n$yaml',
        );
        _assertTaggedCommentsInOrder(orderAB.toString(), emittedTags);
        _assertEditsReplay(yaml, orderAB);
        _assertEditsReplay(yaml, orderBA);
      }
      expect(testedPairs, greaterThan(30),
          reason: 'Expected to test at least 30 disjoint path pairs');
    });
  });
}
