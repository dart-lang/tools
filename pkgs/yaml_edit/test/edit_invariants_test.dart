// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/edit_invariants.dart';
import 'package:yaml_edit/yaml_edit.dart';

void _expectInvariantFailure(
  String initialYaml,
  SourceEdit edit, {
  required EditOperation operation,
  required List<Object?> path,
  required String messageContains,
}) {
  final initialDocument = CstDocument.parse(initialYaml);
  final updatedYaml = edit.offset + edit.length <= initialYaml.length
      ? edit.apply(initialYaml)
      : initialYaml;
  final updatedDocument = CstDocument.parse(updatedYaml);
  expect(
    () => checkEditInvariants(
      initialDocument: initialDocument,
      updatedDocument: updatedDocument,
      edit: edit,
      operation: operation,
      path: path,
    ),
    throwsA(
      isA<AssertionError>().having(
        (e) => '${e.message}',
        'message',
        contains(messageContains),
      ),
    ),
  );
}

void main() {
  group('checkEditInvariants negative tests', () {
    test('rejects out-of-bounds edit range', () {
      _expectInvariantFailure(
        'a: 1\n',
        SourceEdit(0, 99, 'a: 2\n'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'out of bounds',
      );
      _expectInvariantFailure(
        'a: 1\n',
        SourceEdit(99, 0, 'x'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'out of bounds',
      );
    });

    test('rejects flow update escaping entry slot into sibling', () {
      const yaml = '[a, b, c]\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(4, 4, 'x, c'),
        operation: EditOperation.update,
        path: [1],
        messageContains: 'exceeds CST slot end',
      );
    });

    test('rejects flow edit touching closing delimiter', () {
      const yaml = '[a, b]\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(4, 2, 'x]'),
        operation: EditOperation.update,
        path: [1],
        messageContains: 'exceeds CST slot end',
      );
    });

    test('rejects block edit crossing into next entry syntax token', () {
      const yaml = 'a: 1\nb: 2\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(3, 7, '9\nb: 2\n'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'crossed non-comment token',
      );
    });

    test('rejects edit starting before block entry start bound (comment-free)',
        () {
      const yaml = 'a: 1\nb: 2\n';
      // Starts inside `a: 1` when removing `b`.
      _expectInvariantFailure(
        yaml,
        SourceEdit(0, yaml.length, 'a: 1\n'),
        operation: EditOperation.remove,
        path: ['b'],
        messageContains: 'precedes CST slot start',
      );
    });

    test('rejects block map update rewriting its own key', () {
      const yaml = 'a: 1\nb: 2\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(0, 4, '"a": 9'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'precedes CST slot start',
      );
    });

    test('rejects edit starting before block entry lineStart with comment', () {
      const yaml = '# above b\na: 1\n# lead b\nb: 2\n';
      final leadStart = yaml.indexOf('# lead b');
      _expectInvariantFailure(
        yaml,
        SourceEdit(leadStart, yaml.length - leadStart, ''),
        operation: EditOperation.remove,
        path: ['b'],
        messageContains: 'precedes CST slot start',
      );
    });

    test('rejects list insertion overwriting sibling flow tokens', () {
      const yaml = '[a, b]\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(1, 4, 'x, y, b'),
        operation: EditOperation.insert,
        path: [],
        messageContains: 'crossed non-comment token',
      );
    });

    test('rejects map add-key overwriting sibling block value', () {
      const yaml = 'a: 1\nb: 2\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(3, 1, '7\nc: 3'),
        operation: EditOperation.update,
        path: ['c'],
        messageContains: 'crossed non-comment token',
      );
    });

    test('rejects flow removal dropping comment before closing bracket', () {
      const yaml = '[\n  a,\n  b # trail b\n  # before close\n]\n';
      final commaOffset = yaml.indexOf(',');
      final closeOffset = yaml.indexOf(']');
      _expectInvariantFailure(
        yaml,
        SourceEdit(commaOffset, closeOffset - commaOffset, ''),
        operation: EditOperation.remove,
        path: [1],
        messageContains: '# before close',
      );
    });

    test('rejects dropping one of two duplicate comments', () {
      const yaml = 'a: 1 # same\nb: 2 # same\n';
      final bValueStart = yaml.indexOf('2');
      final bLineEnd = yaml.length - 1;
      _expectInvariantFailure(
        yaml,
        SourceEdit(bValueStart, bLineEnd - bValueStart, '9'),
        operation: EditOperation.update,
        path: ['b'],
        messageContains: 'unintentionally removed',
      );
    });

    test('rejects dropping block scalar header comment during update', () {
      const yaml = 'a: |- # header\n  text\nb: 2\n';
      final valueStart = yaml.indexOf('|-');
      final valueEnd = yaml.indexOf('\nb:');
      _expectInvariantFailure(
        yaml,
        SourceEdit(valueStart, valueEnd - valueStart, '9'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: '# header',
      );
    });

    test('rejects block scalar swallowing a trailing comment after edit', () {
      const yaml = 'a: 1\n  # trailing\nb: 2\n';
      final oneOffset = yaml.indexOf('1');
      _expectInvariantFailure(
        yaml,
        SourceEdit(oneOffset, 1, '|-\n  x'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'after edit',
      );
    });

    test('rejects edit corrupting a comment immediately before edit', () {
      const yaml = 'a: # keep\n  1\n';
      final commentEnd = yaml.indexOf('\n');
      final oneEnd = yaml.indexOf('1') + 1;
      _expectInvariantFailure(
        yaml,
        SourceEdit(commentEnd, oneEnd - commentEnd, '2'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'before edit',
      );
    });

    test('rejects dropping a comment during list insertion', () {
      const yaml = '- a # keep\n- b\n';
      final commentStart = yaml.indexOf('# keep');
      final lineEnd = yaml.indexOf('\n') + 1;
      _expectInvariantFailure(
        yaml,
        SourceEdit(commentStart, lineEnd - commentStart, '\n- x\n'),
        operation: EditOperation.insert,
        path: [],
        messageContains: '# keep',
      );
    });

    test('rejects dropping a comment when adding a new mapping key', () {
      const yaml = 'a: 1 # keep\n';
      final commentStart = yaml.indexOf('# keep');
      _expectInvariantFailure(
        yaml,
        SourceEdit(commentStart, yaml.length - commentStart, '\nb: 2\n'),
        operation: EditOperation.update,
        path: ['b'],
        messageContains: '# keep',
      );
    });

    test('rejects dropping comment outside replaced block collection', () {
      const yaml = 'a:\n  b: 1 # inline on b\nc: 2\n';
      final cStart = yaml.indexOf('c:');
      _expectInvariantFailure(
        yaml,
        SourceEdit(
            yaml.indexOf(':') + 1, cStart - yaml.indexOf(':') - 1, ' 9\n'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: '# inline on b',
      );
    });
  });

  group('YamlEditor invariant integration', () {
    test('removes first of duplicate flow-list elements without false positive',
        () {
      final editor = YamlEditor('[a, # c0\n a, # c1\n b]\n');
      editor.remove([0]);
      expect(editor.parseAt([]).value, equals(['a', 'b']));
      expect(editor.toString(), contains('# c1'));
      expect(editor.toString(), isNot(contains('# c0')));
    });

    test('removes first of duplicate block-list elements cleanly', () {
      final editor = YamlEditor('- a # c0\n- a # c1\n- b\n');
      editor.remove([0]);
      expect(editor.parseAt([]).value, equals(['a', 'b']));
      expect(editor.toString(), contains('# c1'));
      expect(editor.toString(), isNot(contains('# c0')));
    });

    test('replacing root of a comments-only document replaces the document',
        () {
      final editor = YamlEditor('# only\n');
      editor.update([], {'a': 1});
      expect(editor.toString(), 'a: 1');
      expect(editor.parseAt([]).value, {'a': 1});
    });

    test('updates document with unknown directive without leaking warnings',
        () {
      final warnings = <String>[];
      final previous = yamlWarningCallback;
      yamlWarningCallback = (msg, [span]) => warnings.add(msg);
      try {
        final editor = YamlEditor('%FOO bar\n---\na: 1 # keep\n');
        warnings.clear();
        editor.update(['a'], 2);
        expect(warnings, isEmpty);
        expect(editor.toString(), contains('# keep'));
      } finally {
        yamlWarningCallback = previous;
      }
    });

    test('preserves surrounding comments across update, insert, and remove',
        () {
      const yaml = '''
# header
items:
  # above a
  - a # inline a
  # above b
  - b # inline b
other: 1 # other
# footer
''';
      final editor = YamlEditor(yaml);
      editor.insertIntoList(['items'], 1, 'mid');
      editor.update(['other'], 2);
      editor.remove(['items', 0]);

      final result = editor.toString();
      expect(result, contains('# header'));
      expect(result, contains('# above a'));
      expect(result, contains('# above b'));
      expect(result, contains('# inline b'));
      expect(result, contains('# other'));
      expect(result, contains('# footer'));
      expect(result, isNot(contains('# inline a')));
    });
  });
}
