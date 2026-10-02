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
  group('frame condition assertions', () {
    test('succeeds when comments outside the edit are preserved', () {
      const yaml = '''
# Header comment
foo: 123 # Inline comment
bar: 456 # Bar comment
# Footer comment
''';
      final editor = YamlEditor(yaml);
      editor.update(['foo'], 999);
      expect(editor.toString(), contains('# Header comment'));
      expect(editor.toString(), contains('# Bar comment'));
      expect(editor.toString(), contains('# Footer comment'));
    });

    test('allows removing comments belonging to the removed map entry', () {
      const yaml = '''
# Header
foo:
  nested: 1 # Foo nested comment
bar: 2 # Bar comment
''';
      final editor = YamlEditor(yaml);
      editor.remove(['foo']);
      expect(editor.toString(), contains('# Header'));
      expect(editor.toString(), contains('# Bar comment'));
      expect(editor.toString(), isNot(contains('# Foo nested comment')));
    });

    test('allows removing comments belonging to the removed list item', () {
      const yaml = '''
# Header
- a # Comment a
- b # Comment b
''';
      final editor = YamlEditor(yaml);
      editor.remove([0]);
      expect(editor.toString(), contains('# Header'));
      expect(editor.toString(), contains('# Comment b'));
      expect(editor.toString(), isNot(contains('# Comment a')));
    });

    test('preserves comment on same-line colon during update', () {
      const yaml = '''
key: # Comment on key line
  value
''';
      final editor = YamlEditor(yaml);
      editor.update(['key'], 'new_value');
      expect(editor.toString(), contains('# Comment on key line'));
      expect(editor.parseAt(['key']).value, equals('new_value'));
    });

    test('preserves pre-comma comment in flow sequence removal', () {
      const yaml = '''
[word1
# comment
, word2]
''';
      final editor = YamlEditor(yaml);
      editor.remove([0]);
      expect(editor.toString(), contains('# comment'));
      expect(editor.parseAt([]).value, equals(['word2']));
    });

    test('succeeds when replacing entire document', () {
      const yaml = '''
# Header
foo: 123
''';
      final editor = YamlEditor(yaml);
      editor.update([], {'bar': 456});
      expect(editor.toString(), contains('bar: 456'));
    });

    test('allows removing list item when list has duplicate values', () {
      const yaml = '''
- a # Comment on first
- a # Comment on second
''';
      final editor = YamlEditor(yaml);
      editor.remove([0]);
      expect(editor.toString(), contains('- a # Comment on second'));
      expect(editor.toString(), isNot(contains('# Comment on first')));
    });

    test('preserves comments during list insertion', () {
      const yaml = '''
- a # Comment a
- b # Comment b
''';
      final editor = YamlEditor(yaml);
      editor.insertIntoList([], 0, 'new_first');
      expect(editor.toString(), contains('# Comment a'));
      expect(editor.toString(), contains('# Comment b'));
    });
  });

  group('CRLF mutations and line ending handling', () {
    test('updates block scalar with header comment in CRLF document', () {
      const yaml = 'key: | # Header comment\r\n  line1\r\n  line2\r\n';
      final editor = YamlEditor(yaml);
      editor.update(['key'], 'new_scalar');
      expect(editor.toString(), contains('# Header comment'));
      expect(editor.toString(), contains('\r\n'));
      expect(editor.parseAt(['key']).value, equals('new_scalar'));
    });

    test('removes sole block entry in CRLF document', () {
      const yaml = 'parent:\r\n  foo: 123\r\n';
      final editor = YamlEditor(yaml);
      editor.remove(['parent', 'foo']);
      expect(editor.toString(), equals('parent:\r\n  {}\r\n'));
    });

    test('removes sole sequence item in CRLF document', () {
      const yaml = 'parent:\r\n  - item\r\n';
      final editor = YamlEditor(yaml);
      editor.remove(['parent', 0]);
      expect(editor.toString(), equals('parent:\r\n  []\r\n'));
    });

    test('updates explicit question mark key without colon to block collection',
        () {
      const yaml = '? explicit_key\n';
      final editor = YamlEditor(yaml);
      editor.update(['explicit_key'], {'nested': 'value'});
      expect(
        editor.parseAt(['explicit_key', 'nested']).value,
        equals('value'),
      );
      final document = CstDocument.parse(editor.toString());
      expect(document.root, isNotNull);
    });

    test(
        'updates explicit question mark key without colon in CRLF to '
        'block collection', () {
      const yaml = '? explicit_key\r\n';
      final editor = YamlEditor(yaml);
      editor.update(['explicit_key'], ['item1', 'item2']);
      expect(editor.parseAt(['explicit_key', 0]).value, equals('item1'));
      expect(editor.parseAt(['explicit_key', 1]).value, equals('item2'));
      final document = CstDocument.parse(editor.toString());
      expect(document.root, isNotNull);
    });

    test('extracts comment without leading space or tab', () {
      const yaml = 'key: value #inline\n';
      final editor = YamlEditor(yaml);
      editor.update(['key'], 'updated');
      expect(editor.toString(), contains('#inline'));
      expect(editor.parseAt(['key']).value, equals('updated'));
    });
  });

  group('CST edge cases and test suite regressions', () {
    test('K858_0: empty strip and clip block scalars can be updated cleanly',
        () {
      const yaml = 'strip: >-\n\nclip: >\n';
      final editor = YamlEditor(yaml);
      editor.update(['strip'], 42);
      expect(editor.parseAt(['strip']).value, equals(42));
      expect(editor.parseAt(['clip']).value, equals(''));
      final document = CstDocument.parse(editor.toString());
      expect(document.root, isNotNull);
    });

    test('H2RW_0: block scalar followed by blank lines with whitespace', () {
      const yaml = 'foo: 1\nbar: 2\n    \n';
      final editor = YamlEditor(yaml);
      editor.update(
        ['bar'],
        YamlScalar.wrap('foo\nbar', style: ScalarStyle.LITERAL),
      );
      expect(editor.parseAt(['bar']).value, equals('foo\nbar'));
      final document = CstDocument.parse(editor.toString());
      expect(document.root, isNotNull);
    });

    test('26DV_0: block mapping with anchor and alias key parses into CST', () {
      const yaml = '&node1 a: 1\n&node2 b: 2\ntop3: &node3\n  *node1 : 3\n';
      final document = CstDocument.parse(yaml);
      expect(document.root, isNotNull);
    });

    test('CstException toString produces informative error message', () {
      final exception = CstException('Test message', 42);
      expect(exception.offset, equals(42));
      expect(exception.message, equals('Test message'));
      expect(exception.toString(), equals('CstException at 42: Test message'));
    });

    test('CST getters and properties', () {
      const source = '# header\n&anchor !tag {a: 1, b: 2} # footer\n';
      final document = CstDocument.parse(source);
      final root = document.root!;
      expect(root.hasProperties, isTrue);
      expect(document.prefixEnd, greaterThan(0));
      expect(document.suffixStart, lessThan(source.length));
      expect(document.tokens, isNotEmpty);
      expect(document.comments, hasLength(2));
      expect(document.lineEnding, equals('\n'));

      if (root case final CstFlowCollection flowCollection) {
        expect(flowCollection.beforeCloseStart, greaterThan(0));
      }

      const crlfSource = 'k: v\r\n';
      final crlfDocument = CstDocument.parse(crlfSource);
      expect(crlfDocument.lineEnding, equals('\r\n'));
    });

    test('replaces block sequence empty value with null', () {
      final editor = YamlEditor('- \n- 2\n');
      editor.update([0], null);
      expect(editor.parseAt([0]).value, isNull);
    });

    test('replaces in place empty value with null', () {
      final editor = YamlEditor('key: # comment\n');
      editor.update(['key'], null);
      expect(editor.parseAt(['key']).value, isNull);
    });

    test('replaces flow empty value with null', () {
      final editor = YamlEditor('[a: ]');
      editor.update([0, 'a'], null);
      expect(editor.parseAt([0, 'a']).value, isNull);
    });

    test('replaces flow map empty value with null', () {
      final editor = YamlEditor('{a: }');
      editor.update(['a'], null);
      expect(editor.parseAt(['a']).value, isNull);
    });

    test('replaces in place collection not starting own line', () {
      final editor = YamlEditor('-   item\n');
      editor.update([0], [1, 2]);
      expect(editor.parseAt([0, 0]).value, equals(1));
    });

    test('replaces block sequence value with properties and equal value', () {
      final editor = YamlEditor('- &anchor 1\n');
      editor.update([0], 1);
      expect(editor.parseAt([0]).value, equals(1));
    });

    test('replaces block map value with properties and equal value', () {
      final editor = YamlEditor('a: &anchor 1\n');
      editor.update(['a'], 1);
      expect(editor.parseAt(['a']).value, equals(1));
    });

    test('PathError thrown for invalid or out-of-bounds paths', () {
      final blockSequenceDocument = CstDocument.parse('- 1\n');
      expect(
        () => buildUpdate(blockSequenceDocument, [5], wrapAsYamlNode(2)),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildUpdate(blockSequenceDocument, [-1], wrapAsYamlNode(2)),
        throwsA(isA<PathError>()),
      );
      expect(
        () =>
            buildUpdate(blockSequenceDocument, ['not-int'], wrapAsYamlNode(2)),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(blockSequenceDocument, [5]),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(blockSequenceDocument, [-1]),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(blockSequenceDocument, ['not-int']),
        throwsA(isA<PathError>()),
      );

      final flowSequenceDocument = CstDocument.parse('[1, 2]');
      expect(
        () => buildUpdate(flowSequenceDocument, [5], wrapAsYamlNode(3)),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildUpdate(flowSequenceDocument, [-1], wrapAsYamlNode(3)),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildUpdate(flowSequenceDocument, ['not-int'], wrapAsYamlNode(3)),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(flowSequenceDocument, [5]),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(flowSequenceDocument, [-1]),
        throwsA(isA<PathError>()),
      );
      expect(
        () => buildRemove(flowSequenceDocument, ['not-int']),
        throwsA(isA<PathError>()),
      );

      final blockMappingDocument = CstDocument.parse('a: 1\n');
      expect(
        () => buildRemove(blockMappingDocument, ['nonexistent']),
        throwsA(isA<PathError>()),
      );

      final flowMappingDocument = CstDocument.parse('{a: 1}');
      expect(
        () => buildRemove(flowMappingDocument, ['nonexistent']),
        throwsA(isA<PathError>()),
      );

      final flowPairDocument = CstDocument.parse('[a: 1]');
      expect(
        () => buildRemove(flowPairDocument, [0, 'nonexistent']),
        throwsA(isA<PathError>()),
      );
    });

    test('replaces block collection value followed by content', () {
      final editor = YamlEditor('a:\n  - 1\nb: 2\n');
      editor.update(['a'], 'simple');
      expect(editor.parseAt(['a']).value, equals('simple'));
      expect(editor.parseAt(['b']).value, equals(2));
    });

    test('CST helper branch exercises', () {
      final emptyDocument = CstDocument.parse('');
      expect(findNode(emptyDocument, ['a', 'b']), isNull);

      final scalarDocument = CstDocument.parse('42');
      expect(findNode(scalarDocument, ['a']), isNull);
      expect(findEntryIndex(scalarDocument.root!, 'key'), isNull);
      expect(mappingPairs(scalarDocument.root!), isNull);

      final sequenceDocument = CstDocument.parse('[1, 2]');
      expect(findNode(sequenceDocument, [5]), isNull);
      expect(findNode(sequenceDocument, [-1]), isNull);
      expect(findNode(sequenceDocument, ['not-int']), isNull);

      final carriageReturnDocument = CstDocument.parse('a: 1\rb: 2');
      expect(carriageReturnDocument.lineBreakLengthBefore(5), equals(1));
      expect(carriageReturnDocument.hasWhitespaceBefore(0), isFalse);
      expect(carriageReturnDocument.hasWhitespaceBefore(-1), isFalse);
      expect(
          carriageReturnDocument.extendPastIndentedCommentsAndBlankLines(1, 0),
          equals(1));

      expect(
        attachHeaderComment('|\r  val', ' # comment', '\r'),
        equals('| # comment\r  val'),
      );
      expect(
        attachHeaderComment('single', ' # comment', '\n'),
        equals('single # comment'),
      );
    });
  });
}
