// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import 'package:source_span/source_span.dart';
import 'package:source_span/src/colors.dart' as colors;

void main() {
  bool oldAscii;
  setUpAll(() {
    oldAscii = glyph.ascii;
    glyph.ascii = true;
  });

  tearDownAll(() {
    glyph.ascii = oldAscii;
  });

  SourceSpan span;
  setUp(() {
    span = SourceSpan(SourceLocation(5, sourceUrl: 'foo.dart'),
        SourceLocation(12, sourceUrl: 'foo.dart'), 'foo bar');
  });

  group('errors', () {
    group('for new SourceSpan()', () {
      test('source URLs must match', () {
        final start = SourceLocation(0, sourceUrl: 'foo.dart');
        final end = SourceLocation(1, sourceUrl: 'bar.dart');
        expect(() => SourceSpan(start, end, '_'), throwsArgumentError);
      });

      test('end must come after start', () {
        final start = SourceLocation(1);
        final end = SourceLocation(0);
        expect(() => SourceSpan(start, end, '_'), throwsArgumentError);
      });

      test('text must be the right length', () {
        final start = SourceLocation(0);
        final end = SourceLocation(1);
        expect(() => SourceSpan(start, end, 'abc'), throwsArgumentError);
      });
    });

    group('for new SourceSpanWithContext()', () {
      test('context must contain text', () {
        final start = SourceLocation(2);
        final end = SourceLocation(5);
        expect(() => SourceSpanWithContext(start, end, 'abc', '--axc--'),
            throwsArgumentError);
      });

      test('text starts at start.column in context', () {
        final start = SourceLocation(3);
        final end = SourceLocation(5);
        expect(() => SourceSpanWithContext(start, end, 'abc', '--abc--'),
            throwsArgumentError);
      });

      test('text starts at start.column of line in multi-line context', () {
        final start = SourceLocation(4, line: 55, column: 3);
        final end = SourceLocation(7, line: 55, column: 6);
        expect(() => SourceSpanWithContext(start, end, 'abc', '\n--abc--'),
            throwsArgumentError);
        expect(() => SourceSpanWithContext(start, end, 'abc', '\n----abc--'),
            throwsArgumentError);
        expect(() => SourceSpanWithContext(start, end, 'abc', '\n\n--abc--'),
            throwsArgumentError);

        // However, these are valid:
        SourceSpanWithContext(start, end, 'abc', '\n---abc--');
        SourceSpanWithContext(start, end, 'abc', '\n\n---abc--');
      });

      test('text can occur multiple times in context', () {
        final start1 = SourceLocation(4, line: 55, column: 2);
        final end1 = SourceLocation(7, line: 55, column: 5);
        final start2 = SourceLocation(4, line: 55, column: 8);
        final end2 = SourceLocation(7, line: 55, column: 11);
        SourceSpanWithContext(start1, end1, 'abc', '--abc---abc--\n');
        SourceSpanWithContext(start1, end1, 'abc', '--abc--abc--\n');
        SourceSpanWithContext(start2, end2, 'abc', '--abc---abc--\n');
        SourceSpanWithContext(start2, end2, 'abc', '---abc--abc--\n');
        expect(
            () => SourceSpanWithContext(start1, end1, 'abc', '---abc--abc--\n'),
            throwsArgumentError);
        expect(
            () => SourceSpanWithContext(start2, end2, 'abc', '--abc--abc--\n'),
            throwsArgumentError);
      });
    });

    group('for union()', () {
      test('source URLs must match', () {
        final other = SourceSpan(SourceLocation(12, sourceUrl: 'bar.dart'),
            SourceLocation(13, sourceUrl: 'bar.dart'), '_');

        expect(() => span.union(other), throwsArgumentError);
      });

      test('spans may not be disjoint', () {
        final other = SourceSpan(SourceLocation(13, sourceUrl: 'foo.dart'),
            SourceLocation(14, sourceUrl: 'foo.dart'), '_');

        expect(() => span.union(other), throwsArgumentError);
      });
    });

    test('for compareTo() source URLs must match', () {
      final other = SourceSpan(SourceLocation(12, sourceUrl: 'bar.dart'),
          SourceLocation(13, sourceUrl: 'bar.dart'), '_');

      expect(() => span.compareTo(other), throwsArgumentError);
    });
  });

  test('fields work correctly', () {
    expect(span.start, equals(SourceLocation(5, sourceUrl: 'foo.dart')));
    expect(span.end, equals(SourceLocation(12, sourceUrl: 'foo.dart')));
    expect(span.sourceUrl, equals(Uri.parse('foo.dart')));
    expect(span.length, equals(7));
  });

  group('union()', () {
    test('works with a preceding adjacent span', () {
      final other = SourceSpan(SourceLocation(0, sourceUrl: 'foo.dart'),
          SourceLocation(5, sourceUrl: 'foo.dart'), 'hey, ');

      final result = span.union(other);
      expect(result.start, equals(other.start));
      expect(result.end, equals(span.end));
      expect(result.text, equals('hey, foo bar'));
    });

    test('works with a preceding overlapping span', () {
      final other = SourceSpan(SourceLocation(0, sourceUrl: 'foo.dart'),
          SourceLocation(8, sourceUrl: 'foo.dart'), 'hey, foo');

      final result = span.union(other);
      expect(result.start, equals(other.start));
      expect(result.end, equals(span.end));
      expect(result.text, equals('hey, foo bar'));
    });

    test('works with a following adjacent span', () {
      final other = SourceSpan(SourceLocation(12, sourceUrl: 'foo.dart'),
          SourceLocation(16, sourceUrl: 'foo.dart'), ' baz');

      final result = span.union(other);
      expect(result.start, equals(span.start));
      expect(result.end, equals(other.end));
      expect(result.text, equals('foo bar baz'));
    });

    test('works with a following overlapping span', () {
      final other = SourceSpan(SourceLocation(9, sourceUrl: 'foo.dart'),
          SourceLocation(16, sourceUrl: 'foo.dart'), 'bar baz');

      final result = span.union(other);
      expect(result.start, equals(span.start));
      expect(result.end, equals(other.end));
      expect(result.text, equals('foo bar baz'));
    });

    test('works with an internal overlapping span', () {
      final other = SourceSpan(SourceLocation(7, sourceUrl: 'foo.dart'),
          SourceLocation(10, sourceUrl: 'foo.dart'), 'o b');

      expect(span.union(other), equals(span));
    });

    test('works with an external overlapping span', () {
      final other = SourceSpan(SourceLocation(0, sourceUrl: 'foo.dart'),
          SourceLocation(16, sourceUrl: 'foo.dart'), 'hey, foo bar baz');

      expect(span.union(other), equals(other));
    });
  });

  group('message()', () {
    test('prints the text being described', () {
      expect(span.message('oh no'), equals("""
line 1, column 6 of foo.dart: oh no
  ,
1 | foo bar
  | ^^^^^^^
  '"""));
    });

    test('gracefully handles a missing source URL', () {
      final span = SourceSpan(SourceLocation(5), SourceLocation(12), 'foo bar');

      expect(span.message('oh no'), equalsIgnoringWhitespace("""
line 1, column 6: oh no
  ,
1 | foo bar
  | ^^^^^^^
  '"""));
    });

    test('gracefully handles empty text', () {
      final span = SourceSpan(SourceLocation(5), SourceLocation(5), '');

      expect(span.message('oh no'), equals('line 1, column 6: oh no'));
    });

    test("doesn't colorize if color is false", () {
      expect(span.message('oh no', color: false), equals("""
line 1, column 6 of foo.dart: oh no
  ,
1 | foo bar
  | ^^^^^^^
  '"""));
    });

    test('colorizes if color is true', () {
      expect(span.message('oh no', color: true), equals("""
line 1, column 6 of foo.dart: oh no
${colors.blue}  ,${colors.none}
${colors.blue}1 |${colors.none} ${colors.red}foo bar${colors.none}
${colors.blue}  |${colors.none} ${colors.red}^^^^^^^${colors.none}
${colors.blue}  '${colors.none}"""));
    });

    test("uses the given color if it's passed", () {
      expect(span.message('oh no', color: colors.yellow), equals("""
line 1, column 6 of foo.dart: oh no
${colors.blue}  ,${colors.none}
${colors.blue}1 |${colors.none} ${colors.yellow}foo bar${colors.none}
${colors.blue}  |${colors.none} ${colors.yellow}^^^^^^^${colors.none}
${colors.blue}  '${colors.none}"""));
    });

    test('with context, underlines the right column', () {
      final spanWithContext = SourceSpanWithContext(
          SourceLocation(5, sourceUrl: 'foo.dart'),
          SourceLocation(12, sourceUrl: 'foo.dart'),
          'foo bar',
          '-----foo bar-----');

      expect(spanWithContext.message('oh no', color: colors.yellow), equals("""
line 1, column 6 of foo.dart: oh no
${colors.blue}  ,${colors.none}
${colors.blue}1 |${colors.none} -----${colors.yellow}foo bar${colors.none}-----
${colors.blue}  |${colors.none} ${colors.yellow}     ^^^^^^^${colors.none}
${colors.blue}  '${colors.none}"""));
    });
  });

  group('compareTo()', () {
    test('sorts by start location first', () {
      final other = SourceSpan(SourceLocation(6, sourceUrl: 'foo.dart'),
          SourceLocation(14, sourceUrl: 'foo.dart'), 'oo bar b');

      expect(span.compareTo(other), lessThan(0));
      expect(other.compareTo(span), greaterThan(0));
    });

    test('sorts by length second', () {
      final other = SourceSpan(SourceLocation(5, sourceUrl: 'foo.dart'),
          SourceLocation(14, sourceUrl: 'foo.dart'), 'foo bar b');

      expect(span.compareTo(other), lessThan(0));
      expect(other.compareTo(span), greaterThan(0));
    });

    test('considers equal spans equal', () {
      expect(span.compareTo(span), equals(0));
    });
  });

  group('equality', () {
    test('two spans with the same locations are equal', () {
      final other = SourceSpan(SourceLocation(5, sourceUrl: 'foo.dart'),
          SourceLocation(12, sourceUrl: 'foo.dart'), 'foo bar');

      expect(span, equals(other));
    });

    test("a different start isn't equal", () {
      final other = SourceSpan(SourceLocation(0, sourceUrl: 'foo.dart'),
          SourceLocation(12, sourceUrl: 'foo.dart'), 'hey, foo bar');

      expect(span, isNot(equals(other)));
    });

    test("a different end isn't equal", () {
      final other = SourceSpan(SourceLocation(5, sourceUrl: 'foo.dart'),
          SourceLocation(16, sourceUrl: 'foo.dart'), 'foo bar baz');

      expect(span, isNot(equals(other)));
    });

    test("a different source URL isn't equal", () {
      final other = SourceSpan(SourceLocation(5, sourceUrl: 'bar.dart'),
          SourceLocation(12, sourceUrl: 'bar.dart'), 'foo bar');

      expect(span, isNot(equals(other)));
    });
  });
}
