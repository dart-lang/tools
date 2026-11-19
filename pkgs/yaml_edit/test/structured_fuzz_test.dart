// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Grammar-guided seeded fuzzing for `package:yaml_edit`.
///
/// Generates YAML documents with tagged comments, block and flow collections,
/// explicit keys, block scalars, anchors/tags, and LF/CRLF line endings, then
/// exercises CST parsing, comment preservation, round-trip updates, insert/
/// remove cancellation, and disjoint update commutativity.
library;

import 'dart:math' show Random;

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Extracts all comment texts from [yaml] via [loadYamlDocumentWithTokens] and
/// checks token stream ordering.
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

/// Grammar-guided generator producing YAML documents with tagged comments.
final class _StructuredYamlGenerator {
  final Random random;
  final String lineEnding;
  int _commentCounter = 0;
  int _anchorCounter = 0;

  _StructuredYamlGenerator(this.random, {this.lineEnding = '\n'});

  String _nextComment(String kind) => '# @${kind}_${_commentCounter++}';

  String _propertyPrefix({String? expectedType}) {
    final roll = random.nextInt(10);
    if (roll == 0) {
      return '&a_${_anchorCounter++} ';
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
      return '!custom ';
    }
    return '';
  }

  /// Generates a rich YAML document with tagged comments and diverse styles.
  String generateDocument({int maxDepth = 3}) {
    _commentCounter = 0;
    _anchorCounter = 0;
    final buffer = StringBuffer();
    // Slot 1: Leading comment before root
    if (random.nextBool()) {
      buffer.write('${_nextComment('header')}$lineEnding');
    }
    if (random.nextBool()) {
      buffer.write(_generateBlockMap(0, maxDepth));
    } else {
      buffer.write(_generateBlockSeq(0, maxDepth));
    }
    buffer.write(lineEnding);
    // Slot 9: Trailing comment at EOF
    if (random.nextBool()) {
      buffer.write('${_nextComment('footer')}$lineEnding');
    }
    return buffer.toString();
  }

  String _generateBlockMap(int indent, int depth) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    for (var index = 0; index < count; index++) {
      final key = 'k_${depth}_$index';
      // Slot 1: Leading comment before map entry
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_map_$key')}');
      }

      final kind = depth > 0 ? random.nextInt(7) : random.nextInt(4);
      if (kind == 0 || depth <= 0) {
        // Simple scalar or explicit question mark key
        final isExplicit = random.nextInt(4) == 0;
        final isEmptyValue = !isExplicit && random.nextInt(5) == 0;
        if (isEmptyValue) {
          // Empty value (CstEmpty)
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('empty_map_$key')}' : '';
          lines.add('$prefix$key:$trailingComment');
        } else if (isExplicit) {
          // Explicit ? key (with or without value)
          final hasValue = random.nextBool();
          if (hasValue) {
            // Slot 2: comment after ?, Slot 3: comment after key
            final afterQuestion =
                random.nextBool() ? ' ${_nextComment('after_q_$key')}' : '';
            final afterKey =
                random.nextBool() ? ' ${_nextComment('after_k_$key')}' : '';
            final scalar = _generateScalar(indent + 2);
            if (afterQuestion.isNotEmpty) {
              lines.add(
                '$prefix?$afterQuestion$lineEnding'
                '$prefix  $key$afterKey$lineEnding'
                '$prefix: $scalar',
              );
            } else {
              lines.add(
                '$prefix? $key$afterKey$lineEnding'
                '$prefix: $scalar',
              );
            }
          } else {
            // Value-less explicit ? key
            final trailingComment =
                random.nextBool() ? ' ${_nextComment('trail_q_$key')}' : '';
            lines.add('$prefix? $key$trailingComment');
          }
        } else {
          final scalar = _generateScalar(indent);
          // Slot 9: Trailing comment on scalar line
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
          lines.add('$prefix$key: $scalar$trailingComment');
        }
      } else if (kind == 1) {
        // Block scalar
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        final blockScalar = _generateBlockScalar(indent + 2, trailingComment);
        lines.add('$prefix$key: $blockScalar');
      } else if (kind == 2) {
        // Slot 4: comment after : before block map
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        lines.add('$prefix$key:$trailingComment');
        lines.add(_generateBlockMap(indent + 2, depth - 1));
      } else if (kind == 3) {
        // Slot 4: comment after : before block seq
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('colon_seq_$key')}' : '';
        lines.add('$prefix$key:$trailingComment');
        lines.add(_generateBlockSeq(indent + 2, depth - 1));
      } else if (kind == 4) {
        // Flow collection
        final flow = _generateFlowCollection(indent + 2);
        lines.add('$prefix$key: $flow');
      } else if (kind == 5) {
        // Compact block sequence under key
        lines.add('$prefix$key:');
        lines.add(
            '$prefix  - compact_item_0$lineEnding$prefix  - compact_item_1');
      } else {
        // Explicit ? key with nested block map value
        lines.add('$prefix? exp_key_${depth}_$index$lineEnding$prefix:');
        lines.add(_generateBlockMap(indent + 2, depth - 1));
      }
    }
    return lines.join(lineEnding);
  }

  String _generateBlockSeq(int indent, int depth) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    for (var index = 0; index < count; index++) {
      // Slot 1: Leading comment before sequence entry
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_seq_$index')}');
      }

      final kind = depth > 0 ? random.nextInt(5) : random.nextInt(3);
      if (kind == 0) {
        // Standard scalar or empty item or next-line scalar
        final isNextLine = random.nextInt(4) == 0;
        final isEmptyItem = !isNextLine && random.nextInt(4) == 0;
        if (isEmptyItem) {
          // Empty sequence item (CstEmpty)
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('empty_seq_$index')}' : '';
          lines.add('$prefix-$trailingComment');
        } else if (isNextLine) {
          // Slot 5: Comment after - before next-line value
          final afterDashComment =
              random.nextBool() ? ' ${_nextComment('after_dash_$index')}' : '';
          final scalar = _generateScalar(indent + 2);
          lines.add('$prefix-$afterDashComment$lineEnding$prefix  $scalar');
        } else {
          final scalar = _generateScalar(indent);
          final trailingComment =
              random.nextBool() ? ' ${_nextComment('trail_seq_$index')}' : '';
          lines.add('$prefix- $scalar$trailingComment');
        }
      } else if (kind == 1) {
        // Block scalar
        final trailingComment =
            random.nextBool() ? ' ${_nextComment('trail_seq_$index')}' : '';
        final blockScalar = _generateBlockScalar(indent + 2, trailingComment);
        lines.add('$prefix- $blockScalar');
      } else if (kind == 2) {
        // Flow collection
        lines.add('$prefix- ${_generateFlowCollection(indent + 2)}');
      } else if (kind == 3) {
        // Compact block map inside sequence
        final key1 = 'ck_${depth}_0';
        final key2 = 'ck_${depth}_1';
        lines.add('$prefix- $key1: ${_generateScalar(indent + 2)}');
        lines.add('$prefix  $key2: ${_generateScalar(indent + 2)}');
      } else {
        // Compact nested block sequence inside sequence (- - a\n  - b)
        lines.add('$prefix- - nested_seq_a');
        lines.add('$prefix  - nested_seq_b');
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
        // Single-pair flow mappings (CstFlowPair) inside flow sequence
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
        return '$property[${items.join(', ')}]';
      }

      final prefix = ' ' * indent;
      final buffer = StringBuffer('$property[$lineEnding');
      for (var index = 0; index < count; index++) {
        // Slot 1: Leading comment inside flow collection
        if (random.nextBool()) {
          buffer.write(
              '$prefix  ${_nextComment('lead_flowseq_$index')}$lineEnding');
        }
        final item = (index == 0 && random.nextBool())
            ? 'pair_k: ${_generateSimpleScalar()}'
            : _generateSimpleScalar();

        if (index < count - 1) {
          // Slot 6: comment before comma, or Slot 7: comment after comma
          if (random.nextBool()) {
            buffer.write(
              '$prefix  $item ${_nextComment('before_comma_$index')}'
              '$lineEnding$prefix  ,$lineEnding',
            );
          } else {
            final afterComma = random.nextBool()
                ? ' ${_nextComment('after_comma_$index')}'
                : '';
            buffer.write('$prefix  $item,$afterComma$lineEnding');
          }
        } else {
          // Trailing item
          final trailingComment = random.nextBool()
              ? ' ${_nextComment('trail_flowseq_$index')}'
              : '';
          buffer.write('$prefix  $item$trailingComment$lineEnding');
        }
      }
      // Slot 10: comment before closing bracket
      if (random.nextBool()) {
        buffer.write('$prefix  ${_nextComment('before_close_seq')}$lineEnding');
      }
      buffer.write('$prefix]');
      return buffer.toString();
    } else {
      if (!isMultiline) {
        final items = List.generate(count, (index) {
          // Empty flow map value
          if (index == 0 && random.nextInt(4) == 0) {
            return 'fk_$index: ';
          }
          final isExplicit = random.nextInt(4) == 0;
          return isExplicit
              ? '? fk_$index: ${_generateSimpleScalar()}'
              : 'fk_$index: ${_generateSimpleScalar()}';
        });
        return '$property{${items.join(', ')}}';
      }

      final prefix = ' ' * indent;
      final buffer = StringBuffer('$property{$lineEnding');
      for (var index = 0; index < count; index++) {
        // Slot 1: Leading comment inside flow map
        if (random.nextBool()) {
          buffer.write(
              '$prefix  ${_nextComment('lead_flowmap_$index')}$lineEnding');
        }
        final isEmptyValue = index == 0 && random.nextInt(4) == 0;
        final pair = isEmptyValue
            ? 'fk_$index: '
            : 'fk_$index: ${_generateSimpleScalar()}';

        if (index < count - 1) {
          // Slot 6: comment before comma, or Slot 7: comment after comma
          if (!isEmptyValue && random.nextBool()) {
            buffer.write(
              '$prefix  $pair ${_nextComment('before_comma_m_$index')}'
              '$lineEnding$prefix  ,$lineEnding',
            );
          } else {
            final afterComma = random.nextBool()
                ? ' ${_nextComment('after_comma_m_$index')}'
                : '';
            buffer.write('$prefix  $pair,$afterComma$lineEnding');
          }
        } else {
          final trailingComment = random.nextBool()
              ? ' ${_nextComment('trail_flowmap_$index')}'
              : '';
          buffer.write('$prefix  $pair$trailingComment$lineEnding');
        }
      }
      // Slot 10: comment before closing brace
      if (random.nextBool()) {
        buffer.write('$prefix  ${_nextComment('before_close_map')}$lineEnding');
      }
      buffer.write('$prefix}');
      return buffer.toString();
    }
  }

  String _generateBlockScalar(int bodyIndent, String trailingComment) {
    final style = random.nextBool() ? '|' : '>';
    final chomp = ['', '-', '+'][random.nextInt(3)];
    final indentIndicator = random.nextBool() ? '2' : '';
    // Slot 8: Comment inside block scalar header
    final headerComment = random.nextBool()
        ? ' ${_nextComment('scalar_header')}'
        : trailingComment;
    final prefix = ' ' * (bodyIndent + (indentIndicator.isNotEmpty ? 2 : 0));
    final extraKeepLines = chomp == '+' ? '$lineEnding$prefix$lineEnding' : '';
    return '$style$chomp$indentIndicator$headerComment$lineEnding'
        '${prefix}line_one_${random.nextInt(100)}$lineEnding'
        '${prefix}line_two_${random.nextInt(100)}$extraKeepLines';
  }

  String _generateScalar(int indent) {
    switch (random.nextInt(5)) {
      case 0:
        return '${_propertyPrefix(expectedType: 'int')}${random.nextInt(1000)}';
      case 1:
        return '${_propertyPrefix(expectedType: 'bool')}'
            '${random.nextBool() ? 'true' : 'false'}';
      case 2:
        return '${_propertyPrefix(expectedType: 'str')}'
            'plain_${random.nextInt(100)}';
      case 3:
        final propertyPrefix = _propertyPrefix(expectedType: 'str');
        return "$propertyPrefix'single_${random.nextInt(100)}'";
      default:
        final propertyPrefix = _propertyPrefix(expectedType: 'str');
        return '$propertyPrefix"double_${random.nextInt(100)}"';
    }
  }

  String _generateSimpleScalar() {
    switch (random.nextInt(3)) {
      case 0:
        return '${_propertyPrefix(expectedType: 'int')}${random.nextInt(100)}';
      case 1:
        final propertyPrefix = _propertyPrefix(expectedType: 'str');
        return "$propertyPrefix's_${random.nextInt(100)}'";
      default:
        final propertyPrefix = _propertyPrefix(expectedType: 'str');
        return '$propertyPrefix"d_${random.nextInt(100)}"';
    }
  }

  Object? generateRandomValue() {
    switch (random.nextInt(6)) {
      case 0:
        return random.nextInt(10000);
      case 1:
        return 'str_${random.nextInt(1000)}';
      case 2:
        return YamlScalar.wrap(
          'block_line_1\nblock_line_2',
          style: random.nextBool() ? ScalarStyle.LITERAL : ScalarStyle.FOLDED,
        );
      case 3:
        return YamlScalar.wrap(
          'quoted_${random.nextInt(100)}',
          style: random.nextBool()
              ? ScalarStyle.SINGLE_QUOTED
              : ScalarStyle.DOUBLE_QUOTED,
        );
      case 4:
        return ['item_${random.nextInt(10)}', random.nextInt(50)];
      default:
        return {'nested_k': 'val_${random.nextInt(50)}'};
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
  group('CST parsing and token stream integrity', () {
    test('generated documents parse cleanly before and after updates', () {
      for (var round = 0; round < 60; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(1001 + round),
          lineEnding: lineEnding,
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        CstDocument.parse(yaml);
        _extractComments(yaml);

        final editor = YamlEditor(yaml);
        final paths =
            _collectPaths(editor).where((path) => path.isNotEmpty).toList();
        if (paths.isEmpty) continue;

        final path = paths[generator.random.nextInt(paths.length)];
        final newValue = generator.generateRandomValue();

        editor.update(path, newValue);
        final afterYaml = editor.toString();

        CstDocument.parse(afterYaml);
        _extractComments(afterYaml);
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
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);

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

          expect(
            _extractComments(editor.toString()),
            equals(initialComments),
            reason: 'Update of scalar path $path to $newValue lost or '
                'reordered comments on round $round step $step!\n'
                'Before:\n$yaml\nAfter:\n${editor.toString()}',
          );
        }
      }
    });

    test('preserves all comments across list insertions and map key additions',
        () {
      for (var round = 0; round < 40; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(2003 + round),
          lineEnding: lineEnding,
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);

        final editor = YamlEditor(yaml);
        final paths = _collectPaths(editor);
        for (final path in paths) {
          final node = editor.parseAt(path);
          if (node is YamlList) {
            final index = generator.random.nextInt(node.length + 1);
            editor.insertIntoList(path, index, 'inserted_$round');
            expect(
              _extractComments(editor.toString()),
              equals(initialComments),
              reason: 'insertIntoList lost comments',
            );
            break;
          } else if (node is YamlMap) {
            editor.update([...path, 'new_key_$round'], 'inserted_val');
            expect(
              _extractComments(editor.toString()),
              equals(initialComments),
              reason: 'Adding map key lost comments',
            );
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
    });

    test('fuzzed removal of every path preserves non-entry comments', () {
      var totalRemovals = 0;
      for (var round = 0; round < 30; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(2004 + round),
          lineEnding: lineEnding,
        );
        final yaml = generator.generateDocument(maxDepth: 2);
        final baseEditor = YamlEditor(yaml);
        final paths =
            _collectPaths(baseEditor).where((path) => path.isNotEmpty).toList();

        for (final path in paths) {
          totalRemovals++;
          final editor = YamlEditor(yaml);
          // YamlEditor's debug-mode checkEditInvariants verifies both CST slot
          // bounds and CST-derived comment conservation on every removal.
          editor.remove(path);
          _extractComments(editor.toString());
        }
      }
      expect(totalRemovals, greaterThan(300));
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
        );
        final yaml = generator.generateDocument(maxDepth: 2);
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
      }
    });

    test('insert-then-remove restores semantics and comments', () {
      for (var round = 0; round < 40; round++) {
        final lineEnding = round.isEven ? '\n' : '\r\n';
        final generator = _StructuredYamlGenerator(
          Random(4004 + round),
          lineEnding: lineEnding,
        );
        final yaml = generator.generateDocument(maxDepth: 2);
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
        );
        final yaml = generator.generateDocument(maxDepth: 2);
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
      }
      expect(testedPairs, greaterThan(30),
          reason: 'Expected to test at least 30 disjoint path pairs');
    });
  });
}
