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
    throwsA(isA<AssertionError>()),
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
      );
      _expectInvariantFailure(
        'a: 1\n',
        SourceEdit(99, 0, 'x'),
        operation: EditOperation.update,
        path: ['a'],
      );
    });

    test('rejects flow update escaping entry slot into sibling', () {
      const yaml = '[a, b, c]\n';
      // Replace "b, c" instead of only "b".
      _expectInvariantFailure(
        yaml,
        SourceEdit(4, 4, 'x, c'),
        operation: EditOperation.update,
        path: [1],
      );
    });

    test('rejects flow edit touching closing delimiter', () {
      const yaml = '[a, b]\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(4, 2, 'x]'),
        operation: EditOperation.update,
        path: [1],
      );
    });

    test('rejects block edit crossing into next entry syntax token', () {
      const yaml = 'a: 1\nb: 2\n';
      // Overwrite across "b: 2" while updating "a".
      _expectInvariantFailure(
        yaml,
        SourceEdit(3, 7, '9\nb: 2\n'),
        operation: EditOperation.update,
        path: ['a'],
      );
    });

    test('rejects edit starting before block entry lineStart', () {
      const yaml = '# above b\na: 1\n# lead b\nb: 2\n';
      // Starts inside "# lead b\n" when removing "b".
      final leadStart = yaml.indexOf('# lead b');
      _expectInvariantFailure(
        yaml,
        SourceEdit(leadStart, yaml.length - leadStart, ''),
        operation: EditOperation.remove,
        path: ['b'],
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
      );
    });

    test('rejects dropping one of two duplicate comments', () {
      const yaml = 'a: 1 # same\nb: 2 # same\n';
      final bValueStart = yaml.indexOf('2');
      final bLineEnd = yaml.length - 1;
      // Drops "# same" on b while the "# same" on a remains.
      _expectInvariantFailure(
        yaml,
        SourceEdit(bValueStart, bLineEnd - bValueStart, '9'),
        operation: EditOperation.update,
        path: ['b'],
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
      );
    });

    test('rejects block scalar swallowing a trailing comment after edit', () {
      const yaml = 'a: 1\n  # trailing\nb: 2\n';
      final oneOffset = yaml.indexOf('1');
      // Replacing "1" with "|-\n  x" swallows "  # trailing" into the scalar!
      _expectInvariantFailure(
        yaml,
        SourceEdit(oneOffset, 1, '|-\n  x'),
        operation: EditOperation.update,
        path: ['a'],
      );
    });

    test('rejects edit corrupting a comment immediately before edit', () {
      const yaml = 'a: # keep\n  1\n';
      final commentEnd = yaml.indexOf('\n');
      final oneEnd = yaml.indexOf('1') + 1;
      // Removing the newline glues "2" onto "# keep" -> "# keep2".
      _expectInvariantFailure(
        yaml,
        SourceEdit(commentEnd, oneEnd - commentEnd, '2'),
        operation: EditOperation.update,
        path: ['a'],
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
      );
    });

    test('rejects dropping comment outside replaced block collection', () {
      const yaml = 'a:\n  b: 1 # inline on b\nc: 2\n';
      final cStart = yaml.indexOf('c:');
      // Overwriting through end of line drops "# inline on b" which sits after
      // a's contentEnd.
      _expectInvariantFailure(
        yaml,
        SourceEdit(
            yaml.indexOf(':') + 1, cStart - yaml.indexOf(':') - 1, ' 9\n'),
        operation: EditOperation.update,
        path: ['a'],
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
