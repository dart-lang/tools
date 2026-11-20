// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/cst_mutations.dart';
import 'package:yaml_edit/src/errors.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('flow collection comment preservation', () {
    test('removing last flow sequence entry keeps comment before close', () {
      final editor =
          YamlEditor('[\n  a,\n  b # trail b\n  # before close\n]\n');
      editor.remove([1]);
      expect(editor.toString(), '[\n  a\n  # before close\n]\n');
      expect(editor.parseAt([]).value, ['a']);
    });

    test('removing last flow sequence entry keeps comments before and after',
        () {
      final editor = YamlEditor(
          '[\n  a,\n  # before b\n  b # trail b\n  # before close\n]\n');
      editor.remove([1]);
      expect(
        editor.toString(),
        '[\n  a,\n  # before b\n  # before close\n]\n',
      );
      expect(editor.parseAt([]).value, ['a']);
    });

    test('removing last flow map entry keeps comment before close', () {
      final editor =
          YamlEditor('{\n  a: 1,\n  b: 2 # trail b\n  # before close\n}\n');
      editor.remove(['b']);
      expect(editor.toString(), '{\n  a: 1\n  # before close\n}\n');
      expect(editor.parseAt([]).value, {'a': 1});
    });

    test('removing middle flow sequence entry keeps comment before next entry',
        () {
      final editor = YamlEditor('[\n  a,\n  b,\n  # before c\n  c\n]\n');
      editor.remove([1]);
      expect(editor.toString(), '[\n  a,\n  # before c\n  c\n]\n');
      expect(editor.parseAt([]).value, ['a', 'c']);
    });

    test('updating empty flow map value keeps inline comment', () {
      final editor = YamlEditor('{\n  a: # c\n  , b: 1}\n');
      editor.update(['a'], 1);
      expect(editor.toString(), '{\n  a: 1 # c\n  , b: 1}\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 1});
    });
  });

  group('block scalar transitions and header comments', () {
    test('replacing clip block scalar with inline scalar adds no blank line',
        () {
      final editor = YamlEditor('a: |\n  text\nb: 1\n');
      editor.update(['a'], 'x');
      expect(editor.toString(), 'a: x\nb: 1\n');
      expect(editor.parseAt([]).value, {'a': 'x', 'b': 1});
    });

    test('replacing empty block scalar preserves line break (K858_0)', () {
      final editor = YamlEditor('strip: |-\nclip: |\nkeep: |+\n');
      editor.update(['clip'], 'x');
      expect(editor.toString(), 'strip: |-\nclip: x\nkeep: |+\n');
      expect(
        editor.parseAt([]).value,
        {'strip': '', 'clip': 'x', 'keep': ''},
      );
    });

    test('replacing block scalar with header comment keeps comment inline', () {
      final editor = YamlEditor('a: |- # c\n  text\nb: 2\n');
      editor.update(['a'], 1);
      expect(editor.toString(), 'a: 1 # c\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 2});
    });

    test('replacing keep block scalar with header comment keeps comment inline',
        () {
      final editor = YamlEditor('a: |+ # c\n  text\n\nb: 2\n');
      editor.update(['a'], 1);
      expect(editor.toString(), 'a: 1 # c\n\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 2});
    });

    test('lifts inline trailing comment onto literal block scalar header', () {
      final editor = YamlEditor('a: 1 # keep\nb: 2\n');
      editor.update(
        ['a'],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: |- # keep\n  x\n  y\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 'x\ny', 'b': 2});
    });

    test('preserves CRLF headers when lifting comment onto block scalar', () {
      final editor = YamlEditor('a: 1 # keep\r\nb: 2\r\n');
      editor.update(
        ['a'],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: |- # keep\r\n  x\r\n  y\r\nb: 2\r\n');
      expect(editor.parseAt([]).value, {'a': 'x\ny', 'b': 2});
    });
  });

  group('block scalar swallowing prevention', () {
    test('handles over-indented comment after blank line (H2RW_0)', () {
      final editor = YamlEditor('a: 1\n\n    # comment\nb: 2\n');
      editor.update(
        ['a'],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: |-\n  x\n  y\n\n# comment\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 'x\ny', 'b': 2});
    });

    test('re-indents over-indented comment to entry column, not column 0', () {
      final editor = YamlEditor('root:\n  a: 1\n    # deep\n  b: 2\n');
      editor.update(
        ['root', 'a'],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(
        editor.toString(),
        'root:\n  a: |-\n    x\n    y\n  # deep\n  b: 2\n',
      );
      expect(editor.parseAt([]).value, {
        'root': {'a': 'x\ny', 'b': 2}
      });
    });

    test('does not move comments when updating to a plain block map', () {
      final editor =
          YamlEditor('a:\n  b: 1\n  # trailing comment about b\nc: 2\n');
      editor.update(['a'], {'x': 1});
      expect(
        editor.toString(),
        'a:\n  x: 1\n  # trailing comment about b\nc: 2\n',
      );
      expect(editor.parseAt([]).value, {
        'a': {'x': 1},
        'c': 2,
      });
    });

    test('uses emitted body indent for sequence block scalar updates', () {
      final editor = YamlEditor('- 1\n  # c\n- 2\n');
      editor.update(
        [0],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), '- |-\n    x\n    y\n  # c\n- 2\n');
      expect(editor.parseAt([]).value, ['x\ny', 2]);
    });

    test('does not eat blank line on zero-length block scalar insertion', () {
      final editor = YamlEditor('a: 1\n\n# comment\n');
      editor.update(
        ['b'],
        wrapAsYamlNode('x\ny', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: 1\nb: |-\n  x\n  y\n\n# comment\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 'x\ny'});
    });
  });

  group('indentation, explicit keys, flow pairs, and aliases', () {
    test('appending compact map to 4-space indented list produces valid YAML',
        () {
      final editor = YamlEditor('a:\n    b: 1\nc:\n    - x\n');
      editor.appendToList(['c'], {'d': 1, 'e': 2});
      expect(editor.parseAt([]).value, {
        'a': {'b': 1},
        'c': [
          'x',
          {'d': 1, 'e': 2},
        ],
      });
    });

    test('updating 3-space indented list item to map produces valid YAML', () {
      final editor = YamlEditor('a:\n   b: 1\nc:\n   - x\n');
      editor.update(['c', 0], {'d': 1, 'e': 2});
      expect(editor.parseAt([]).value, {
        'a': {'b': 1},
        'c': [
          {'d': 1, 'e': 2},
        ],
      });
    });

    test('updates explicit key without colon', () {
      final editor = YamlEditor('? a\n? b\n');
      editor.update(['a'], 1);
      expect(editor.parseAt([]).value, {'a': 1, 'b': null});
    });

    test('updates, extends, and removes flow pairs', () {
      final editor = YamlEditor('[a: 1]\n');
      editor.update([0, 'a'], 2);
      expect(editor.toString(), '[a: 2]\n');

      editor.update([0, 'b'], 3);
      expect(editor.toString(), '[{a: 2, b: 3}]\n');
      expect(editor.parseAt([]).value, [
        {'a': 2, 'b': 3}
      ]);

      final editor2 = YamlEditor('[a: 1]\n');
      editor2.remove([0, 'a']);
      expect(editor2.toString(), '[{}]\n');
      expect(editor2.parseAt([]).value, [<Object?, Object?>{}]);
    });

    test('inserting alphabetically into anchored block map works', () {
      final editor = YamlEditor('a: &x\n  b: 1\n  c: 2\n');
      editor.update(['a', 'aa'], 0);
      expect(editor.toString(), 'a: &x\n  aa: 0\n  b: 1\n  c: 2\n');
    });

    test('updating a node containing only alias references succeeds', () {
      final editor = YamlEditor('a: &x 1\nb: [*x, 2]\n');
      editor.update(['b'], 3);
      expect(editor.toString(), 'a: &x 1\nb: 3\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 3});
    });

    test('updating a direct alias reference succeeds', () {
      final editor = YamlEditor('a: &x 1\nb: *x\n');
      editor.update(['b'], 2);
      expect(editor.toString(), 'a: &x 1\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 1, 'b': 2});
    });

    test('updating a referenced anchor throws AliasException', () {
      final editor = YamlEditor('a: &x 1\nb: *x\n');
      expect(() => editor.update(['a'], 2), throwsA(isA<AliasException>()));
    });

    test('updating a collection containing a referenced anchor throws', () {
      final editor = YamlEditor('a: [&x 1, 2]\nb: *x\n');
      expect(() => editor.update(['a'], 3), throwsA(isA<AliasException>()));
    });

    test('updating a nested alias reference succeeds', () {
      final editor = YamlEditor('a: &x 1\nr:\n  b: *x\n');
      editor.update(['r', 'b'], 2);
      expect(editor.toString(), 'a: &x 1\nr:\n  b: 2\n');
      expect(editor.parseAt([]).value, {
        'a': 1,
        'r': {'b': 2},
      });

      final siblingEditor = YamlEditor('r:\n  a: &x 1\n  b: *x\n');
      siblingEditor.update(['r', 'b'], 2);
      expect(siblingEditor.toString(), 'r:\n  a: &x 1\n  b: 2\n');
    });

    test('updating inside a referenced anchored collection throws', () {
      final editor = YamlEditor('r: &anc\n  b: 1\nother: *anc\n');
      expect(
          () => editor.update(['r', 'b'], 2), throwsA(isA<AliasException>()));
    });

    test('extra-indented last line in literal scalar avoids comment swallowing',
        () {
      final editor = YamlEditor('a: 1\n  # c\nb: 2\n');
      editor.update(
        ['a'],
        wrapAsYamlNode('x\n  y', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: |-\n  x\n    y\n# c\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': 'x\n  y', 'b': 2});
    });

    test('preserves pre-comma comment in flow sequence removal', () {
      final editor = YamlEditor('[word1\n# comment\n, word2]\n');
      editor.remove([0]);
      expect(editor.toString(), '[\n# comment\nword2]\n');
      expect(editor.parseAt([]).value, ['word2']);
    });

    test('standalone comma after comment leaves no junk whitespace', () {
      final sameLineNext = YamlEditor('[\n  a\n  # c\n  , b\n]\n');
      sameLineNext.remove([0]);
      expect(sameLineNext.toString(), '[\n  # c\n  b\n]\n');
      expect(sameLineNext.parseAt([]).value, ['b']);

      final nextLineNext = YamlEditor('[\n  a\n  # c\n  ,\n  b\n]\n');
      nextLineNext.remove([0]);
      expect(nextLineNext.toString(), '[\n  # c\n  b\n]\n');
      expect(nextLineNext.parseAt([]).value, ['b']);

      final withCommaComment =
          YamlEditor('[\n  a\n  # c\n  , # drop\n  b\n]\n');
      withCommaComment.remove([0]);
      expect(withCommaComment.toString(), '[\n  # c\n  b\n]\n');
      expect(withCommaComment.parseAt([]).value, ['b']);

      final multilineWithInlineBeforeComma =
          YamlEditor("[\n  'foo\nbar' # inline\n  , b\n]\n");
      multilineWithInlineBeforeComma.remove([0]);
      expect(multilineWithInlineBeforeComma.toString(), '[ b\n]\n');
      expect(multilineWithInlineBeforeComma.parseAt([]).value, ['b']);
    });

    test('preserves leading comments around standalone comma in flow map', () {
      final editor =
          YamlEditor('{\n  # lead a\n  a: 1\n  ,\n  # lead b\n  b: 2\n}\n');
      editor.remove(['a']);
      expect(editor.toString(), '{\n  # lead a\n  # lead b\n  b: 2\n}\n');
      expect(editor.parseAt([]).value, {'b': 2});
    });

    test('updates block scalar with header comment in CRLF document', () {
      final editor =
          YamlEditor('key: | # Header comment\r\n  line1\r\n  line2\r\n');
      editor.update(['key'], 'new_scalar');
      expect(editor.toString(), 'key: new_scalar # Header comment\r\n');
      expect(editor.parseAt(['key']).value, 'new_scalar');
    });

    test(
        'preserves trailing comma and multiline closing bracket on flow remove',
        () {
      final trailingMap = YamlEditor('{a: 1, b: 2,}');
      trailingMap.remove(['b']);
      expect(trailingMap.toString(), '{a: 1,}');

      final multilineTrailing = YamlEditor('[\n  a,\n  b, # c\n]\n');
      multilineTrailing.remove([1]);
      expect(multilineTrailing.toString(), '[\n  a,\n]\n');

      final multilineNoTrailing = YamlEditor('[\n  a,\n  b # c\n]\n');
      multilineNoTrailing.remove([1]);
      expect(multilineNoTrailing.toString(), '[\n  a\n]\n');

      final multilineTrailingBeforeClose = YamlEditor(
        '[\n  a,\n  b, # trail b\n  # before close\n]\n',
      );
      multilineTrailingBeforeClose.remove([1]);
      expect(
        multilineTrailingBeforeClose.toString(),
        '[\n  a,\n  # before close\n]\n',
      );

      final firstWithCommaComment = YamlEditor(
        '"map": {\n  "foo": 42, # drop\n  "bar": "baz"\n}\n',
      );
      firstWithCommaComment.remove(['map', 'foo']);
      expect(
        firstWithCommaComment.toString(),
        '"map": {\n  "bar": "baz"\n}\n',
      );

      final ownership = YamlEditor('[\n  a, # c1\n  b, # c2\n  c # c3\n]\n');
      ownership.remove([1]);
      expect(ownership.toString(), '[\n  a, # c1\n  c # c3\n]\n');

      final inlineMiddle = YamlEditor('[a, b, # c2\n c]\n');
      inlineMiddle.remove([1]);
      expect(inlineMiddle.toString(), '[a, \n c]\n');
      expect(inlineMiddle.parseAt([]).value, ['a', 'c']);

      final inlineMiddleNextLineComment = YamlEditor('[a, b,\n# keep\n c]\n');
      inlineMiddleNextLineComment.remove([1]);
      expect(inlineMiddleNextLineComment.toString(), '[a, \n# keep\n c]\n');
      expect(inlineMiddleNextLineComment.parseAt([]).value, ['a', 'c']);

      // Plain scalars inside multiline flow collections include trailing
      // whitespace/newlines in package:yaml spans; updates and removals must
      // keep the closing delimiter on its own line.
      final flowPlainUpdate = YamlEditor('[\nfoo: bar\n]\n');
      flowPlainUpdate.update([0], 42);
      expect(flowPlainUpdate.toString(), '[\n42\n]\n');

      final flowPlainIndentedUpdate = YamlEditor('- [\n  foo\n  ]\n');
      flowPlainIndentedUpdate.update([0, 0], 42);
      expect(flowPlainIndentedUpdate.toString(), '- [\n  42\n  ]\n');

      final flowPlainRemoveLast = YamlEditor('key1: [\n  1,\n  2\n]\n');
      flowPlainRemoveLast.remove(['key1', 1]);
      expect(flowPlainRemoveLast.toString(), 'key1: [\n  1\n]\n');

      // Replacing a nested block collection inside a block sequence must not
      // emit a stray newline that pushes its trailing comment onto a new line.
      final seqCollectionUpdate =
          YamlEditor('- - one # Compact\n  - two # sequence\n- three\n');
      seqCollectionUpdate.update([0], 42);
      expect(seqCollectionUpdate.toString(), '- 42 # sequence\n- three\n');

      // Updating a bare `?` explicit key at the end of a multiline flow map
      // keeps `}` on its own line (DFF7_0).
      final bareExplicitFlow = YamlEditor('{\n  a: 1,\n  ?\n}\n');
      bareExplicitFlow.update([null], 42);
      expect(bareExplicitFlow.toString(), '{\n  a: 1,\n  ?\n: 42\n}\n');

      // Removing a leading-comma last flow entry leaves no spaces-only line
      // (mangled_json.yaml).
      final leadingCommaLast = YamlEditor('{\n  a: 1\n    , b: 2\n}\n');
      leadingCommaLast.remove(['b']);
      expect(leadingCommaLast.toString(), '{\n  a: 1\n}\n');
    });

    test('removes sole entry of zero-indented block sequence in compact map',
        () {
      // Regression from dart-lang/tools .github/labeler.yml.
      final labeler =
          YamlEditor("a:\n  - changed-files:\n    - any-glob: 'x'\n");
      labeler.remove(['a', 0, 'changed-files', 0]);
      expect(labeler.toString(), 'a:\n  - changed-files:\n      []\n');
      expect(labeler.parseAt([]).value, {
        'a': [
          {'changed-files': <Object?>[]},
        ],
      });

      final nested = YamlEditor('a:\n  b:\n  - 1\n');
      nested.remove(['a', 'b', 0]);
      expect(nested.toString(), 'a:\n  b:\n    []\n');

      final rootLevel = YamlEditor('key:\n- 1\n');
      rootLevel.remove(['key', 0]);
      expect(rootLevel.toString(), 'key:\n  []\n');

      final commentedRootSeq = YamlEditor('# comment\n- 1\n');
      commentedRootSeq.remove([0]);
      expect(commentedRootSeq.toString(), '# comment\n[]\n');
    });

    test('detects anchored map keys and flow-pair anchors on remove and update',
        () {
      final anchoredKey = YamlEditor('r:\n  &k a: 1\nother: *k\n');
      expect(() => anchoredKey.remove(['r']), throwsA(isA<AliasException>()));

      final complexAnchoredKey = YamlEditor('r:\n  [&k a]: 1\nother: *k\n');
      expect(
        () => complexAnchoredKey.remove(['r']),
        throwsA(isA<AliasException>()),
      );

      final flowPairAnchor = YamlEditor('a: [&k b: 1]\nc: *k\n');
      expect(
        () => flowPairAnchor.update(['a'], 2),
        throwsA(isA<AliasException>()),
      );
    });

    test('attaches comment onto single-line empty block scalar replacement',
        () {
      final editor = YamlEditor('a: 1 # keep\nb: 2\n');
      editor.update(
        ['a'],
        wrapAsYamlNode('', scalarStyle: ScalarStyle.LITERAL),
      );
      expect(editor.toString(), 'a: "" # keep\nb: 2\n');
      expect(editor.parseAt([]).value, {'a': '', 'b': 2});
    });

    test('updates and removes explicit keys cleanly', () {
      final updateEditor = YamlEditor('? a\n: 1\n');
      updateEditor.update(['a'], 2);
      expect(updateEditor.toString(), '? a\n: 2\n');

      final removeEditor = YamlEditor('? a\n: 1\n? b\n: 2\n');
      removeEditor.remove(['a']);
      expect(removeEditor.toString(), '? b\n: 2\n');
    });

    test('replaces root scalar with block map preserving trailing newline', () {
      final editor = YamlEditor('a\n');
      editor.update([], {'x': 1});
      expect(editor.toString(), 'x: 1\n');
    });

    test(
        'replaying editor.edits reproduces toString across CRLF and root edits',
        () {
      for (final (initial, run) in <(String, void Function(YamlEditor))>[
        (
          'a: 1 # c\r\nb: |\r\n  x\r\n  y\r\n',
          (e) {
            e.update(['a'], 2);
            e.remove(['b']);
          },
        ),
        (
          'a: 1 # c\n',
          (e) => e.update([], 'z'),
        ),
      ]) {
        final editor = YamlEditor(initial);
        run(editor);
        expect(SourceEdit.applyAll(initial, editor.edits), editor.toString());
      }
    });

    test('updates explicit key without colon to block collection (LF and CRLF)',
        () {
      final lfEditor = YamlEditor('? explicit_key\n');
      lfEditor.update(['explicit_key'], {'nested': 'value'});
      expect(lfEditor.parseAt(['explicit_key', 'nested']).value, 'value');

      final crlfEditor = YamlEditor('? explicit_key\r\n');
      crlfEditor.update(['explicit_key'], ['item1', 'item2']);
      expect(crlfEditor.parseAt(['explicit_key']).value, ['item1', 'item2']);
    });

    test('replaces empty values with null across block and flow collections',
        () {
      for (final (yaml, path) in [
        ('- \n- 2\n', <Object?>[0]),
        ('key: # comment\n', <Object?>['key']),
        ('[a: ]', <Object?>[0, 'a']),
        ('{a: }', <Object?>['a']),
      ]) {
        final editor = YamlEditor(yaml);
        editor.update(path, null);
        expect(editor.parseAt(path).value, isNull);
      }
    });

    test('updates extra-spaced block sequence entry and anchored equal values',
        () {
      final spaced = YamlEditor('-   item\n');
      spaced.update([0], [1, 2]);
      expect(spaced.parseAt([0]).value, [1, 2]);

      final spacedEmptyBlock = YamlEditor('-   item\n');
      spacedEmptyBlock.update(
        [0],
        wrapAsYamlNode(<Object?>[], collectionStyle: CollectionStyle.BLOCK),
      );
      expect(spacedEmptyBlock.toString(), '-   []\n');

      final nextLineFlowMap = YamlEditor("-\n  'item'\n- {}\n");
      nextLineFlowMap.update(
        [0],
        wrapAsYamlNode({'a': 1}, collectionStyle: CollectionStyle.FLOW),
      );
      expect(nextLineFlowMap.toString(), '-\n  {a: 1}\n- {}\n');

      final commentedMapFlowVal = YamlEditor('a: # keep\n  1\nb: 2\n');
      commentedMapFlowVal.update(
        ['a'],
        wrapAsYamlNode([1, 2], collectionStyle: CollectionStyle.FLOW),
      );
      expect(commentedMapFlowVal.toString(), 'a: # keep\n  [1, 2]\nb: 2\n');

      final anchoredSeq = YamlEditor('- &anchor 1\n');
      anchoredSeq.update([0], 1);
      expect(anchoredSeq.parseAt([0]).value, 1);

      final anchoredMap = YamlEditor('a: &anchor 1\n');
      anchoredMap.update(['a'], 1);
      expect(anchoredMap.parseAt(['a']).value, 1);
    });

    test('buildUpdate and buildRemove throw PathError on invalid paths', () {
      final blockSeq = CstDocument.parse('- 1\n');
      final flowSeq = CstDocument.parse('[1, 2]');
      final blockMap = CstDocument.parse('a: 1\n');
      final flowMap = CstDocument.parse('{a: 1}');
      final flowPair = CstDocument.parse('[a: 1]');

      for (final badStep in <Object?>[5, -1, 'not-int']) {
        expect(() => buildUpdate(blockSeq, [badStep], wrapAsYamlNode(2)),
            throwsA(isA<PathError>()));
        expect(
            () => buildRemove(blockSeq, [badStep]), throwsA(isA<PathError>()));
        expect(() => buildUpdate(flowSeq, [badStep], wrapAsYamlNode(3)),
            throwsA(isA<PathError>()));
        expect(
            () => buildRemove(flowSeq, [badStep]), throwsA(isA<PathError>()));
      }
      expect(() => buildRemove(blockMap, ['nonexistent']),
          throwsA(isA<PathError>()));
      expect(() => buildRemove(flowMap, ['nonexistent']),
          throwsA(isA<PathError>()));
      expect(() => buildRemove(flowPair, [0, 'nonexistent']),
          throwsA(isA<PathError>()));
    });
  });
}
