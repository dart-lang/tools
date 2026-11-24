// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
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

void _expectInvariantsPass(
  String initialYaml,
  SourceEdit edit, {
  required EditOperation operation,
  required List<Object?> path,
}) {
  final initialDocument = CstDocument.parse(initialYaml);
  final updatedDocument = CstDocument.parse(edit.apply(initialYaml));
  expect(
    checkEditInvariants(
      initialDocument: initialDocument,
      updatedDocument: updatedDocument,
      edit: edit,
      operation: operation,
      path: path,
    ),
    isTrue,
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

    test('rejects flow removal dropping sibling entry trailing comment', () {
      const yaml = '[\n  a, # keep a\n  b # trail b\n]\n';
      final commaOffset = yaml.indexOf(',');
      final closeOffset = yaml.indexOf(']');
      _expectInvariantFailure(
        yaml,
        SourceEdit(commaOffset, closeOffset - commaOffset, '\n'),
        operation: EditOperation.remove,
        path: [1],
        messageContains: '# keep a',
      );
    });

    test('falls back to collection bounds for out-of-range block-seq step', () {
      const yaml = 'a:\n  - 1\n  - 2\n';
      _expectInvariantFailure(
        yaml,
        SourceEdit(0, 2, 'b:'),
        operation: EditOperation.update,
        path: ['a', 99],
        messageContains: 'precedes CST slot start',
      );
    });

    test('accepts edits when parent is a scalar without slot bounds', () {
      const yaml = 'a: 1\n';
      final initial = CstDocument.parse(yaml);
      final edit = SourceEdit(3, 1, '2');
      final updated = CstDocument.parse(edit.apply(yaml));
      expect(
        checkEditInvariants(
          initialDocument: initial,
          updatedDocument: updated,
          edit: edit,
          operation: EditOperation.update,
          path: ['a', 'nested'],
        ),
        isTrue,
      );
    });

    test('rejects flow remove escaping removed entry neighborhood', () {
      const yaml = '[a, b, c]\n';
      // Starts inside `a` when removing `b`.
      _expectInvariantFailure(
        yaml,
        SourceEdit(1, 5, 'a, '),
        operation: EditOperation.remove,
        path: [1],
        messageContains: 'precedes CST slot start',
      );
      // Extends into `c` when removing `b`.
      _expectInvariantFailure(
        yaml,
        SourceEdit(4, 4, 'c'),
        operation: EditOperation.remove,
        path: [1],
        messageContains: 'exceeds CST slot end',
      );
    });

    test('rejects pure insertion deleting existing bytes', () {
      _expectInvariantFailure(
        '[a, b]\n',
        SourceEdit(3, 1, ' x, '),
        operation: EditOperation.insert,
        path: [],
        messageContains: 'Pure insertion',
      );
      _expectInvariantFailure(
        'a: 1\n',
        SourceEdit(4, 1, '\nb: 2\n'),
        operation: EditOperation.update,
        path: ['b'],
        messageContains: 'Pure insertion',
      );
    });

    test('rejects shifting untouched sibling or closing delimiter off its line',
        () {
      // Collapsing opening newline onto sibling entry (json_comments.yaml bug).
      const mapYaml = 'map: {\n  foo: 42, # c\n  bar: baz\n}\n';
      final openEnd = mapYaml.indexOf('{') + 1;
      final afterComment = mapYaml.indexOf('\n  bar') + 1;
      _expectInvariantFailure(
        mapYaml,
        SourceEdit(openEnd, afterComment - openEnd, ''),
        operation: EditOperation.remove,
        path: ['map', 'foo'],
        messageContains: 'Sibling flow entry 1',
      );

      // Pulling closing `]` onto previous entry's line.
      const listYaml = '[\n  a,\n  b # c\n]\n';
      final commaOffset = listYaml.indexOf(',');
      final closeOffset = listYaml.indexOf(']');
      _expectInvariantFailure(
        listYaml,
        SourceEdit(commaOffset, closeOffset - commaOffset, ''),
        operation: EditOperation.remove,
        path: [1],
        messageContains: 'Flow closing delimiter',
      );

      // Shifting a block sequence entry off column 2 to column 1.
      const seqYaml = 'a:\n  - 1\n';
      _expectInvariantFailure(
        seqYaml,
        SourceEdit(4, 0, '- 0\n'),
        operation: EditOperation.insert,
        path: ['a'],
        messageContains: 'Sibling sequence entry 0',
      );
    });

    test('rejects flipping comment placement between inline and own-line', () {
      // Pushing an inline block-scalar header comment onto its own line.
      const headerYaml = 'a: |- # hdr\n  text\nb: 2\n';
      final start = headerYaml.indexOf('|-');
      final end = headerYaml.indexOf('\nb:');
      _expectInvariantFailure(
        headerYaml,
        SourceEdit(start, end - start, '1\n# hdr'),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'inline -> own-line',
      );

      // Gluing an own-line comment onto a code line.
      const ownLineYaml = 'a: 1\n# own\nb: 2\n';
      final oneOffset = ownLineYaml.indexOf('1');
      final hashOffset = ownLineYaml.indexOf('# own');
      _expectInvariantFailure(
        ownLineYaml,
        SourceEdit(oneOffset, hashOffset - oneOffset, '2 '),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'own-line -> inline',
      );
    });

    test('rejects mismatched line endings in uniform-EOL documents', () {
      const crlfYaml = 'a: 1\r\nb: 2\r\n';
      _expectInvariantFailure(
        crlfYaml,
        SourceEdit(crlfYaml.length, 0, 'c: 3\n'),
        operation: EditOperation.update,
        path: ['c'],
        messageContains: 'LF line break in a CRLF document',
      );
      const lfYaml = 'a: 1\nb: 2\n';
      _expectInvariantFailure(
        lfYaml,
        SourceEdit(lfYaml.length, 0, 'c: 3\r\n'),
        operation: EditOperation.update,
        path: ['c'],
        messageContains: 'CRLF line break in an LF document',
      );
    });

    test('rejects dropping trailing comma on last flow entry removal', () {
      const yaml = '{a: 1, b: 2,}';
      final commaOffset = yaml.indexOf(',');
      final closeOffset = yaml.indexOf('}');
      _expectInvariantFailure(
        yaml,
        SourceEdit(commaOffset, closeOffset - commaOffset, ''),
        operation: EditOperation.remove,
        path: ['b'],
        messageContains: 'dropped the trailing comma',
      );
    });

    test('rejects introducing a non-empty whitespace-only line', () {
      const yaml = '[\n  a\n  # c\n  , b\n]\n';
      final aOffset = yaml.indexOf('a');
      final commaEnd = yaml.indexOf(',') + 1;
      _expectInvariantFailure(
        yaml,
        SourceEdit(aOffset, commaEnd - aOffset, '\n  # c\n  '),
        operation: EditOperation.remove,
        path: [0],
        messageContains: 'whitespace-only line',
      );

      // Pure deletion starting at a line start leaving trailing spaces behind.
      _expectInvariantFailure(
        'a: 1\nb: 2   \n',
        SourceEdit(5, 4, ''),
        operation: EditOperation.remove,
        path: ['b'],
        messageContains: 'whitespace-only line',
      );

      // Pure deletion leaving leading spaces before the line break behind.
      _expectInvariantFailure(
        '  a: 1\n',
        SourceEdit(2, 4, ''),
        operation: EditOperation.remove,
        path: ['a'],
        messageContains: 'whitespace-only line',
      );

      // Appending a trailing whitespace-only line after a plain scalar.
      _expectInvariantFailure(
        'a: 1',
        SourceEdit(3, 1, '2\n  '),
        operation: EditOperation.update,
        path: ['a'],
        messageContains: 'whitespace-only line',
      );
    });

    test('allows pre-existing trailing whitespace-only line on block append',
        () {
      _expectInvariantsPass(
        'a: 1\n  ',
        SourceEdit(5, 0, 'c: 3\n'),
        operation: EditOperation.update,
        path: ['c'],
      );
      _expectInvariantsPass(
        '- 1\n  ',
        SourceEdit(4, 0, '- 2\n'),
        operation: EditOperation.insert,
        path: [1],
      );
    });

    test(
        'compact first-entry removal still rejects gluing unrelated own-line '
        'comment inline', () {
      // Single-entry compact sequence has no second entry, so `# footer` sits
      // outside any compact-lift gap and must not be pulled inline.
      const yaml = '- - 0\n# footer\n';
      final zeroStart = yaml.indexOf('- 0');
      final footerStart = yaml.indexOf('# footer');
      _expectInvariantFailure(
        yaml,
        SourceEdit(zeroStart, footerStart - zeroStart, '[] '),
        operation: EditOperation.remove,
        path: [0, 0],
        messageContains: 'own-line -> inline',
      );
    });
  });
}
