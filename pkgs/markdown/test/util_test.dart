// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('String.toLines()', () {
    test('a single line without a line ending', () {
      const text = 'Foo';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
      ]);
    });

    test('a single line with a line ending', () {
      const text = 'Foo\n';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
      ]);
    });

    test('multiple lines with a blank line in between', () {
      const text = 'Foo\r\n\nBar';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
        {'content': '', 'isBlankLine': true},
        {'content': 'Bar', 'isBlankLine': false},
      ]);
    });
  });

  group('Line.isBlankLine', () {
    test('only ASCII spaces and tabs count as a blank line', () {
      for (final input in ['', ' ', '\t', ' \t  \t']) {
        expect(Line(input).isBlankLine, isTrue, reason: input);
      }
      for (final input in ['a', ' a ', '\u00a0', '\u2003', ' \tb']) {
        expect(Line(input).isBlankLine, isFalse, reason: input);
      }
    });

    test('large blank and nonblank lines are classified correctly', () {
      expect(Line(' ' * 20000).isBlankLine, isTrue);
      expect(Line(' ' * 20000 + 'x').isBlankLine, isFalse);
    });
  });

  group('String.dedent()', () {
    test('preserves partial tab indentation', () {
      final partial = '  \ttext'.dedent(3);
      expect(partial.text, 'text');
      expect(partial.tabRemaining, 3);
    });

    test('handles spaces, tabs and non-whitespace prefixes', () {
      expect('    text'.dedent().text, 'text');
      expect('\ttext'.dedent().text, 'text');
      expect('\ttext'.dedent().tabRemaining, 0);
      expect('  text'.dedent().text, 'text');
      expect('text'.dedent().text, 'text');
      expect('\u00a0 text'.dedent().text, '\u00a0 text');
      expect('  \ttext'.dedent(0).text, '  \ttext');
      expect(' x'.dedent(-1).text, ' x');
    });
  });

  group('String.indentation()', () {
    test('only spaces', () {
      expect('   '.indentation(), 3);
      expect('    '.indentation(), 4);
      expect('     '.indentation(), 5);
    });

    test('spaces and tabs', () {
      expect('\t  '.indentation(), 6);
      expect(' \t '.indentation(), 5);
      expect('  \t'.indentation(), 4);
      expect('\t\t  '.indentation(), 10);
      expect(' \t\t '.indentation(), 9);
      expect('  \t\t'.indentation(), 8);
    });

    test('spaces, tabs and non whitespace characters', () {
      expect('\t  foo'.indentation(), 6);
      expect(' \t foo'.indentation(), 5);
      expect('  \tfoo'.indentation(), 4);
    });
  });
}

extension on Line {
  Map<String, dynamic> toMap() => {
    'content': content,
    'isBlankLine': isBlankLine,
    if (tabRemaining != null) 'tabRemaining': tabRemaining,
  };
}
