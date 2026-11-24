// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml_edit/src/cst.dart';
import 'package:yaml_edit/src/cst_helpers.dart';

void main() {
  group('CstDocumentTextHelpers', () {
    test('lineBreakLengthAt and lineBreakLengthBefore handle LF, CR, CRLF', () {
      final lfDoc = CstDocument.parse('a: 1\nb: 2\n');
      expect(lfDoc.lineBreakLengthAt(4), 1);
      expect(lfDoc.hasLineBreakAt(4), isTrue);
      expect(lfDoc.lineBreakLengthAt(3), 0);
      expect(lfDoc.lineBreakLengthAt(-1), 0);
      expect(lfDoc.lineBreakLengthAt(lfDoc.source.length), 0);
      expect(lfDoc.lineBreakLengthBefore(5), 1);
      expect(lfDoc.hasLineBreakBefore(5), isTrue);
      expect(lfDoc.lineBreakLengthBefore(0), 0);

      final crlfDoc = CstDocument.parse('a: 1\r\nb: 2\r\n');
      expect(crlfDoc.lineBreakLengthAt(4), 2);
      expect(crlfDoc.lineBreakLengthAt(5), 1);
      expect(crlfDoc.lineBreakLengthBefore(6), 2);
      expect(crlfDoc.lineBreakLengthBefore(5), 1);
      expect(crlfDoc.lineBreakLengthBefore(crlfDoc.source.length), 2);

      final crDoc = CstDocument.parse('a: 1\rb: 2\r');
      expect(crDoc.lineBreakLengthAt(4), 1);
      expect(crDoc.lineBreakLengthBefore(5), 1);
      expect(crDoc.lineBreakLengthBefore(crDoc.source.length), 1);
    });

    test('hasLineBreakInRange, hasWhitespaceBefore, trimmedEnd, startsOwnLine',
        () {
      const yaml = '  a: [1  \n  ]\n  b:\t2\n';
      final doc = CstDocument.parse(yaml);
      expect(doc.hasLineBreakInRange(0, 0), isFalse);
      expect(doc.hasLineBreakInRange(0, 9), isFalse);
      expect(doc.hasLineBreakInRange(0, 10), isTrue);
      expect(doc.hasLineBreakInRange(9, 10), isTrue);

      expect(doc.hasWhitespaceBefore(0), isFalse);
      expect(doc.hasWhitespaceBefore(2), isTrue);
      expect(doc.hasWhitespaceBefore(3), isFalse);
      final twoOffset = yaml.indexOf('2');
      expect(doc.hasWhitespaceBefore(twoOffset), isTrue); // tab before '2'

      expect(doc.trimmedEnd(6, 12), 7);
      expect(doc.startsOwnLine(2), isTrue);
      expect(doc.startsOwnLine(3), isFalse);
      expect(doc.startsOwnLine(yaml.indexOf('b')), isTrue);
      expect(doc.hasTabInRange(0, yaml.indexOf('b')), isFalse);
      expect(doc.hasTabInRange(yaml.indexOf('b'), twoOffset), isTrue);
    });

    test('extendPastIndentedCommentsAndBlankLines handles blank-line modes',
        () {
      const yaml = 'a: 1\n  # nested\n\n  # nested 2\n\nb: 2\n';
      final doc = CstDocument.parse(yaml);
      final afterFirstLine = yaml.indexOf('  # nested');
      final beforeB = yaml.indexOf('b: 2');
      final beforeTrailingBlank = yaml.indexOf('\nb: 2');

      expect(
        doc.extendPastIndentedCommentsAndBlankLines(
          afterFirstLine,
          0,
          preserveTrailingBlankLines: false,
        ),
        beforeB,
      );
      expect(
        doc.extendPastIndentedCommentsAndBlankLines(
          afterFirstLine,
          0,
          preserveTrailingBlankLines: true,
        ),
        beforeTrailingBlank,
      );
    });
  });

  group('LayoutStyle.of', () {
    test('infers indentStep and lineEnding from nested block collections', () {
      final fourSpace = CstDocument.parse('a:\r\n    b: 1\r\n');
      final style = LayoutStyle.of(fourSpace);
      expect(style.indentStep, 4);
      expect(style.lineEnding, '\r\n');

      final flat = CstDocument.parse('a: 1\n');
      expect(LayoutStyle.of(flat).indentStep, 2);
      expect(LayoutStyle.of(flat).lineEnding, '\n');
    });
  });

  group('collectAliasedValues and navigation', () {
    test('collects only nodes referenced by an alias', () {
      final doc = CstDocument.parse('a: &used 1\nb: &unused 2\nc: *used\n');
      final root = doc.root as CstBlockMap;
      final aliased = collectAliasedValues(doc);
      expect(aliased, contains(root.entries[0].value.value));
      expect(aliased, isNot(contains(root.entries[1].value.value)));
    });

    test('findNode and findEntryIndex navigate block and flow structures', () {
      final doc = CstDocument.parse('a:\n  - {k: 1}\n  - [x: 2]\n');
      expect(findNode(doc, ['a', 0, 'k'])?.value.value, 1);
      expect(findNode(doc, ['a', 1, 0, 'x'])?.value.value, 2);
      expect(findNode(doc, ['missing']), isNull);
      expect(findEntryIndex(doc.root!, 'a'), 0);
      expect(findEntryIndex(doc.root!, 'missing'), isNull);
    });
  });
}
