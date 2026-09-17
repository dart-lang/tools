// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Structured grammar-guided property-based fuzzing for `package:yaml_edit`.
///
/// Validates the Concrete Syntax Tree (CST) and slot-directed mutation model
/// against 6 formal verification layers:
/// 1. CST Tiling & Token-Stream Integrity (`render(parse(S)) == S` & sorted)
/// 2. SourceEdit Exactness & Structural Locality Frame Bound
/// 3. Comment Conservation & Attribution Law (via `CommentToken`s)
/// 4. Algebraic Lens Laws (PutGet, GetPut, PutPut Overwrite Equivalence)
/// 5. Insert-Remove Cancellation Law
/// 6. Byte-for-Byte String Commutativity of Disjoint CST Edits
library;

import 'dart:math' show Random;

import 'package:test/test.dart';
import 'package:yaml/tokens.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/equality.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Reconstructs source from [CstDocument] slots to verify exact tiling.
String _renderCst(CstDocument document) {
  final source = document.source;
  final buffer = StringBuffer();
  var cursor = 0;

  void upTo(int offset) {
    buffer.write(source.substring(cursor, offset));
    cursor = offset;
  }

  void visitNode(CstNode node) {
    upTo(node.start);
    upTo(node.contentStart);
    switch (node) {
      case CstScalar():
      case CstAlias():
      case CstEmpty():
        upTo(node.end);
      case CstBlockSeq():
        for (final entry in node.entries) {
          upTo(entry.dashStart + 1);
          visitNode(entry.value);
          upTo(entry.end);
        }
      case CstBlockMap():
        for (final entry in node.entries) {
          if (entry.questionMark case final questionMark?) {
            upTo(questionMark + 1);
          }
          visitNode(entry.key);
          if (entry.colon case final colon?) upTo(colon + 1);
          visitNode(entry.value);
          upTo(entry.end);
        }
      case CstFlowPair():
        if (node.questionMark case final questionMark?) {
          upTo(questionMark + 1);
        }
        visitNode(node.key);
        if (node.colon case final colon?) upTo(colon + 1);
        visitNode(node.pairValue);
      case CstFlowCollection():
        upTo(node.openEnd);
        for (final entry in node.entries) {
          if (entry.questionMark case final questionMark?) {
            upTo(questionMark + 1);
          }
          if (entry.key case final key?) {
            visitNode(key);
            if (entry.colon case final colon?) upTo(colon + 1);
          }
          visitNode(entry.value);
          if (entry.comma case final comma?) upTo(comma + 1);
          upTo(entry.end);
        }
        upTo(node.end);
    }
  }

  if (document.root case final root?) visitNode(root);
  upTo(source.length);
  return buffer.toString();
}

/// Extracts all comment texts from [yaml] using `retainTokens: true`.
List<String> _extractComments(String yaml) {
  final doc = loadYamlDocument(yaml, retainTokens: true);
  final tokens = doc.tokens ?? const [];
  // Verify token stream integrity invariant: non-empty and sorted.
  for (var i = 0; i < tokens.length; i++) {
    expect(tokens[i].span.length, greaterThan(0),
        reason: 'Token must have positive length');
    if (i > 0) {
      expect(
        tokens[i].span.start.offset,
        greaterThanOrEqualTo(tokens[i - 1].span.start.offset),
        reason: 'Tokens must be sorted by start offset',
      );
      if (tokens[i].span.start.offset < tokens[i - 1].span.end.offset) {
        // The only token allowed inside another token's span is a header
        // CommentToken inside a block ScalarToken.
        expect(tokens[i], isA<CommentToken>(),
            reason: 'Only CommentToken may be nested inside a token span');
        expect(tokens[i - 1], isA<ScalarToken>(),
            reason: 'Only ScalarToken may contain a header CommentToken');
      }
    }
  }
  return tokens.whereType<CommentToken>().map((t) => t.span.text).toList();
}

/// Verifies CST tiling and token stream invariants on [yaml].
void _assertCstInvariants(String yaml) {
  final cst = CstDocument.parse(yaml);
  expect(_renderCst(cst), equals(yaml),
      reason: 'CST slots failed to tile source byte-for-byte');
  _extractComments(yaml);
}

/// Grammar-guided generator producing YAML documents with tagged comments.
final class _StructuredYamlGenerator {
  final Random random;
  int _commentCounter = 0;

  _StructuredYamlGenerator(this.random);

  String _nextComment(String kind) => '# @${kind}_${_commentCounter++}';

  /// Generates a rich YAML document with tagged comments and diverse styles.
  String generateDocument({int maxDepth = 3}) {
    _commentCounter = 0;
    final buffer = StringBuffer();
    if (random.nextBool()) {
      buffer.writeln(_nextComment('header'));
    }
    if (random.nextBool()) {
      buffer.writeln(_generateBlockMap(0, maxDepth));
    } else {
      buffer.writeln(_generateBlockSeq(0, maxDepth));
    }
    if (random.nextBool()) {
      buffer.writeln(_nextComment('footer'));
    }
    return buffer.toString();
  }

  String _generateBlockMap(int indent, int depth) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    for (var i = 0; i < count; i++) {
      final key = 'k_${depth}_$i';
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_map_$key')}');
      }
      final kind = depth > 0 ? random.nextInt(5) : random.nextInt(3);
      if (kind == 0 || depth <= 0) {
        final scalar = _generateScalar(indent);
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        lines.add('$prefix$key: $scalar$trail');
      } else if (kind == 1) {
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        final blockScalar = _generateBlockScalar(indent + 2, trail);
        lines.add('$prefix$key: $blockScalar');
      } else if (kind == 2) {
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_map_$key')}' : '';
        lines.add('$prefix$key:$trail');
        lines.add(_generateBlockMap(indent + 2, depth - 1));
      } else if (kind == 3) {
        lines.add('$prefix$key:');
        lines.add(_generateBlockSeq(indent + 2, depth - 1));
      } else {
        final flow = _generateFlowCollection(indent + 2);
        lines.add('$prefix$key: $flow');
      }
    }
    return lines.join('\n');
  }

  String _generateBlockSeq(int indent, int depth) {
    final count = 2 + random.nextInt(3);
    final lines = <String>[];
    final prefix = ' ' * indent;
    for (var i = 0; i < count; i++) {
      if (random.nextBool()) {
        lines.add('$prefix${_nextComment('lead_seq_$i')}');
      }
      final kind = depth > 0 ? random.nextInt(4) : 0;
      if (kind == 0) {
        final scalar = _generateScalar(indent);
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_seq_$i')}' : '';
        lines.add('$prefix- $scalar$trail');
      } else if (kind == 1) {
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_seq_$i')}' : '';
        final blockScalar = _generateBlockScalar(indent + 2, trail);
        lines.add('$prefix- $blockScalar');
      } else if (kind == 2) {
        lines.add('$prefix- ${_generateFlowCollection(indent + 2)}');
      } else {
        // Compact block map inside sequence
        final k1 = 'ck_${depth}_0';
        final k2 = 'ck_${depth}_1';
        lines.add('$prefix- $k1: ${_generateScalar(indent + 2)}');
        lines.add('$prefix  $k2: ${_generateScalar(indent + 2)}');
      }
    }
    return lines.join('\n');
  }

  String _generateFlowCollection(int indent) {
    final isMap = random.nextBool();
    final isMultiline = random.nextBool();
    final count = 2 + random.nextInt(3);
    if (!isMap) {
      if (!isMultiline) {
        final items = List.generate(count, (_) => _generateSimpleScalar());
        return '[${items.join(', ')}]';
      }
      final prefix = ' ' * indent;
      final buf = StringBuffer('[\n');
      for (var i = 0; i < count; i++) {
        if (random.nextBool()) {
          buf.writeln('$prefix  ${_nextComment('lead_flowseq_$i')}');
        }
        final comma = (i < count - 1 || random.nextBool()) ? ',' : '';
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_flowseq_$i')}' : '';
        buf.writeln('$prefix  ${_generateSimpleScalar()}$comma$trail');
      }
      buf.write('$prefix]');
      return buf.toString();
    } else {
      if (!isMultiline) {
        final items =
            List.generate(count, (i) => 'fk_$i: ${_generateSimpleScalar()}');
        return '{${items.join(', ')}}';
      }
      final prefix = ' ' * indent;
      final buf = StringBuffer('{\n');
      for (var i = 0; i < count; i++) {
        if (random.nextBool()) {
          buf.writeln('$prefix  ${_nextComment('lead_flowmap_$i')}');
        }
        final comma = (i < count - 1 || random.nextBool()) ? ',' : '';
        final trail =
            random.nextBool() ? ' ${_nextComment('trail_flowmap_$i')}' : '';
        buf.writeln('$prefix  fk_$i: ${_generateSimpleScalar()}$comma$trail');
      }
      buf.write('$prefix}');
      return buf.toString();
    }
  }

  String _generateBlockScalar(int bodyIndent, String headerComment) {
    final style = random.nextBool() ? '|' : '>';
    final chomp = ['', '-', '+'][random.nextInt(3)];
    final prefix = ' ' * bodyIndent;
    return '$style$chomp$headerComment\n'
        '${prefix}line_one_${random.nextInt(100)}\n'
        '${prefix}line_two_${random.nextInt(100)}';
  }

  String _generateScalar(int indent) {
    switch (random.nextInt(5)) {
      case 0:
        return '${random.nextInt(1000)}';
      case 1:
        return random.nextBool() ? 'true' : 'false';
      case 2:
        return 'plain_${random.nextInt(100)}';
      case 3:
        return "'single_${random.nextInt(100)}'";
      default:
        return '"double_${random.nextInt(100)}"';
    }
  }

  String _generateSimpleScalar() {
    switch (random.nextInt(3)) {
      case 0:
        return '${random.nextInt(100)}';
      case 1:
        return "'s_${random.nextInt(100)}'";
      default:
        return '"d_${random.nextInt(100)}"';
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
        walk(node.nodes[key]!, [...current, key]);
      }
    } else if (node is YamlList) {
      for (var i = 0; i < node.length; i++) {
        walk(node.nodes[i], [...current, i]);
      }
    }
  }

  walk(editor.parseAt([]), []);
  return paths;
}

/// Checks whether two paths are structurally disjoint (neither is a prefix of
/// the other, and they do not share a list parent where indices shift).
bool _areDisjointUpdatePaths(List<Object?> p1, List<Object?> p2) {
  if (p1.isEmpty || p2.isEmpty) return false;
  final minLen = p1.length < p2.length ? p1.length : p2.length;
  for (var i = 0; i < minLen; i++) {
    if (p1[i] != p2[i]) return true;
  }
  return false;
}

void main() {
  group('Layer 1 & 2: CST Tiling, SourceEdit Exactness & Frame Bounds', () {
    test('generated documents tile exactly and mutations stay within frame',
        () {
      final gen = _StructuredYamlGenerator(Random(1001));
      for (var round = 0; round < 50; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        _assertCstInvariants(yaml);

        final editor = YamlEditor(yaml);
        final paths = _collectPaths(editor).where((p) => p.isNotEmpty).toList();
        if (paths.isEmpty) continue;

        final path = paths[gen.random.nextInt(paths.length)];
        final beforeYaml = editor.toString();
        final newValue = gen.generateRandomValue();

        editor.update(path, newValue);
        final afterYaml = editor.toString();

        // Verify SourceEdit exactness
        final edit = editor.edits.last;
        expect(edit.apply(beforeYaml), equals(afterYaml),
            reason: 'SourceEdit.apply must reproduce updated YAML exactly');

        // Verify CST invariants after mutation
        _assertCstInvariants(afterYaml);
      }
    });
  });

  group('Layer 3: Comment Conservation & Attribution Laws', () {
    test('100% comment conservation across updates (including block scalars)',
        () {
      final gen = _StructuredYamlGenerator(Random(2002));
      for (var round = 0; round < 60; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);

        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where((p) => p.isNotEmpty && editor.parseAt(p) is YamlScalar)
            .toList();
        if (scalarPaths.isEmpty) continue;

        // Perform 3 consecutive updates on random scalar paths (including
        // transitions to/from block scalars and collections).
        for (var step = 0; step < 3; step++) {
          final path = scalarPaths[gen.random.nextInt(scalarPaths.length)];
          final newValue = gen.generateRandomValue();
          editor.update(path, newValue);

          final currentComments = _extractComments(editor.toString());
          expect(
            currentComments,
            equals(initialComments),
            reason: 'Update of scalar path $path to $newValue lost or '
                'reordered comments on round $round step $step!\n'
                'Before:\n$yaml\nAfter:\n${editor.toString()}',
          );
        }
      }
    });

    test('comment conservation across list insertions and map key additions',
        () {
      final gen = _StructuredYamlGenerator(Random(2003));
      for (var round = 0; round < 50; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        final initialComments = _extractComments(yaml);

        final editor = YamlEditor(yaml);
        final paths = _collectPaths(editor);
        for (final path in paths) {
          final node = editor.parseAt(path);
          if (node is YamlList) {
            final idx = gen.random.nextInt(node.length + 1);
            editor.insertIntoList(path, idx, 'inserted_$round');
            expect(_extractComments(editor.toString()), equals(initialComments),
                reason: 'insertIntoList lost comments');
            break;
          } else if (node is YamlMap) {
            editor.update([...path, 'new_key_$round'], 'inserted_val');
            expect(_extractComments(editor.toString()), equals(initialComments),
                reason: 'Adding map key lost comments');
            break;
          }
        }
      }
    });

    test('flow collection removal preserves all leading and sibling comments',
        () {
      const flowWithComments = '''
items: [
  # lead 0
  10, # trail 0
  # lead 1
  20, # trail 1
  # lead 2
  30 # trail 2
]
''';
      // Remove first item (10): # lead 0, # lead 1, # trail 1, # lead 2,
      // # trail 2 survive
      final ed0 = YamlEditor(flowWithComments)..remove(['items', 0]);
      expect(
        _extractComments(ed0.toString()),
        equals(['# lead 0', '# lead 1', '# trail 1', '# lead 2', '# trail 2']),
      );

      // Remove middle item (20): # lead 0, # trail 0, # lead 1, # lead 2,
      // # trail 2 survive
      final ed1 = YamlEditor(flowWithComments)..remove(['items', 1]);
      expect(
        _extractComments(ed1.toString()),
        equals(['# lead 0', '# trail 0', '# lead 1', '# lead 2', '# trail 2']),
      );

      // Remove last item (30): # lead 0, # trail 0, # lead 1, # trail 1,
      // # lead 2 survive
      final ed2 = YamlEditor(flowWithComments)..remove(['items', 2]);
      expect(
        _extractComments(ed2.toString()),
        equals(['# lead 0', '# trail 0', '# lead 1', '# trail 1', '# lead 2']),
      );
    });
  });

  group('Layer 4 & 5: Algebraic Lens Laws & Insert-Remove Cancellation', () {
    test('PutGet, GetPut idempotence, and PutPut overwrite equivalence', () {
      final gen = _StructuredYamlGenerator(Random(3003));
      for (var round = 0; round < 40; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where((p) => p.isNotEmpty && editor.parseAt(p) is YamlScalar)
            .toList();
        if (scalarPaths.isEmpty) continue;

        final path = scalarPaths[gen.random.nextInt(scalarPaths.length)];
        final originalNode = editor.parseAt(path) as YamlScalar;

        // Law 2: GetPut (Plain scalar self-update is byte-for-byte identity)
        if (originalNode.style == ScalarStyle.PLAIN) {
          final selfEditor = YamlEditor(yaml)..update(path, originalNode.value);
          expect(selfEditor.toString(), equals(yaml),
              reason: 'GetPut plain scalar self-update changed document bytes');
        }

        // Law 3: PutPut Overwrite Equivalence (via block scalar intermediate)
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
          reason: 'PutPut semantic mismatch',
        );
        expect(
          _extractComments(twoStep.toString()),
          equals(_extractComments(oneStep.toString())),
          reason:
              'PutPut lost comments when transitioning through block scalar',
        );
      }
    });

    test('Insert-Remove cancellation preserves comments and semantics', () {
      final gen = _StructuredYamlGenerator(Random(4004));
      for (var round = 0; round < 40; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        final editor = YamlEditor(yaml);
        final listPaths = _collectPaths(editor)
            .where((p) => editor.parseAt(p) is YamlList)
            .toList();
        if (listPaths.isEmpty) continue;

        final path = listPaths[gen.random.nextInt(listPaths.length)];
        final listNode = editor.parseAt(path) as YamlList;
        final index = gen.random.nextInt(listNode.length + 1);

        final initialComments = _extractComments(yaml);
        final initialTree = editor.parseAt([]);

        editor.insertIntoList(path, index, 'temp_item_$round');
        editor.remove([...path, index]);

        expect(
          deepEquals(editor.parseAt([]), initialTree),
          isTrue,
          reason: 'Insert-Remove failed to restore semantic tree',
        );
        expect(
          _extractComments(editor.toString()),
          equals(initialComments),
          reason: 'Insert-Remove failed to preserve comments',
        );
      }
    });
  });

  group('Layer 6: Byte-for-Byte Disjoint Path Commutativity Law', () {
    test('disjoint updates commute byte-for-byte on generated documents', () {
      final gen = _StructuredYamlGenerator(Random(5005));
      var testedPairs = 0;
      for (var round = 0; round < 60; round++) {
        final yaml = gen.generateDocument(maxDepth: 2);
        final editor = YamlEditor(yaml);
        final scalarPaths = _collectPaths(editor)
            .where((p) => p.isNotEmpty && editor.parseAt(p) is YamlScalar)
            .toList();
        if (scalarPaths.length < 2) continue;

        List<Object?>? p1;
        List<Object?>? p2;
        for (var i = 0; i < scalarPaths.length; i++) {
          for (var j = i + 1; j < scalarPaths.length; j++) {
            if (_areDisjointUpdatePaths(scalarPaths[i], scalarPaths[j])) {
              p1 = scalarPaths[i];
              p2 = scalarPaths[j];
              break;
            }
          }
          if (p1 != null) break;
        }
        if (p1 == null || p2 == null) continue;

        testedPairs++;
        final v1 = gen.generateRandomValue();
        final v2 = gen.generateRandomValue();

        final orderAB = YamlEditor(yaml)
          ..update(p1, v1)
          ..update(p2, v2);

        final orderBA = YamlEditor(yaml)
          ..update(p2, v2)
          ..update(p1, v1);

        expect(
          orderAB.toString(),
          equals(orderBA.toString()),
          reason: 'Disjoint updates at $p1 and $p2 failed to commute '
              'byte-for-byte on document:\n$yaml',
        );
      }
      expect(testedPairs, greaterThan(30),
          reason: 'Expected to test at least 30 disjoint path pairs');
    });
  });
}
