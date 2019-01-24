// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';

import 'package:source_span/source_span.dart';
import 'package:source_span/src/colors.dart' as colors;

main() {
  bool oldAscii;
  setUpAll(() {
    oldAscii = glyph.ascii;
    glyph.ascii = true;
  });

  tearDownAll(() {
    glyph.ascii = oldAscii;
  });

  var file;
  setUp(() {
    file = new SourceFile.fromString("""
foo bar baz
whiz bang boom
zip zap zop
""");
  });

  test("points to the span in the source", () {
    expect(file.span(4, 7).highlight(), equals("""
  ,
1 | foo bar baz
  |     ^^^
  '"""));
  });

  test("gracefully handles a missing source URL", () {
    var span = new SourceFile.fromString("foo bar baz").span(4, 7);
    expect(span.highlight(), equals("""
  ,
1 | foo bar baz
  |     ^^^
  '"""));
  });

  test("works for a point span", () {
    expect(file.location(4).pointSpan().highlight(), equals("""
  ,
1 | foo bar baz
  |     ^
  '"""));
  });

  test("works for a point span at the beginning of the file", () {
    expect(file.location(0).pointSpan().highlight(), equals("""
  ,
1 | foo bar baz
  | ^
  '"""));
  });

  test("works for a point span at the end of a line", () {
    expect(file.location(11).pointSpan().highlight(), equals("""
  ,
1 | foo bar baz
  |            ^
  '"""));
  });

  test("works for a point span at the end of the file", () {
    expect(file.location(38).pointSpan().highlight(), equals("""
  ,
3 | zip zap zop
  |            ^
  '"""));
  });

  test("works for a point span after the end of the file", () {
    expect(file.location(39).pointSpan().highlight(), equals("""
  ,
3 | zip zap zop
  |            ^
  '"""));
  });

  test("works for a point span at the end of the file with no trailing newline",
      () {
    file = new SourceFile.fromString("zip zap zop");
    expect(file.location(10).pointSpan().highlight(), equals("""
  ,
1 | zip zap zop
  |           ^
  '"""));
  });

  test(
      "works for a point span after the end of the file with no trailing newline",
      () {
    file = new SourceFile.fromString("zip zap zop");
    expect(file.location(11).pointSpan().highlight(), equals("""
  ,
1 | zip zap zop
  |            ^
  '"""));
  });

  test("works for a point span in an empty file", () {
    expect(new SourceFile.fromString("").location(0).pointSpan().highlight(),
        equals("""
  ,
1 | 
  | ^
  '"""));
  });

  test("works for a single-line file without a newline", () {
    expect(
        new SourceFile.fromString("foo bar").span(0, 7).highlight(), equals("""
  ,
1 | foo bar
  | ^^^^^^^
  '"""));
  });

  group("with a multiline span", () {
    test("highlights the middle of the first and last lines", () {
      expect(file.span(4, 34).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz bang boom
3 | | zip zap zop
  | '-------^
  '"""));
    });

    test("works when it begins at the end of a line", () {
      expect(file.span(11, 34).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,------------^
2 | | whiz bang boom
3 | | zip zap zop
  | '-------^
  '"""));
    });

    test("works when it ends at the beginning of a line", () {
      expect(file.span(4, 28).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz bang boom
3 | | zip zap zop
  | '-^
  '"""));
    });

    test("highlights the full first line", () {
      expect(file.span(0, 34).highlight(), equals("""
  ,
1 | / foo bar baz
2 | | whiz bang boom
3 | | zip zap zop
  | '-------^
  '"""));
    });

    test("highlights the full first line even if it's indented", () {
      var file = new SourceFile.fromString("""
  foo bar baz
  whiz bang boom
  zip zap zop
""");

      expect(file.span(2, 38).highlight(), equals("""
  ,
1 | /   foo bar baz
2 | |   whiz bang boom
3 | |   zip zap zop
  | '-------^
  '"""));
    });

    test("highlights the full first line if it's empty", () {
      var file = new SourceFile.fromString("""
foo

bar
""");

      expect(file.span(4, 9).highlight(), equals("""
  ,
2 | / 
3 | \\ bar
  '"""));
    });

    test("highlights the full last line", () {
      expect(file.span(4, 27).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | \\ whiz bang boom
  '"""));
    });

    test("highlights the full last line with no trailing newline", () {
      expect(file.span(4, 26).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | \\ whiz bang boom
  '"""));
    });

    test("highlights the full last line with a trailing Windows newline", () {
      var file = new SourceFile.fromString("""
foo bar baz\r
whiz bang boom\r
zip zap zop\r
""");

      expect(file.span(4, 29).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | \\ whiz bang boom
  '"""));
    });

    test("highlights the full last line at the end of the file", () {
      expect(file.span(4, 39).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz bang boom
3 | \\ zip zap zop
  '"""));
    });

    test(
        "highlights the full last line at the end of the file with no trailing "
        "newline", () {
      var file = new SourceFile.fromString("""
foo bar baz
whiz bang boom
zip zap zop""");

      expect(file.span(4, 38).highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz bang boom
3 | \\ zip zap zop
  '"""));
    });

    test("highlights the full last line if it's empty", () {
      var file = new SourceFile.fromString("""
foo

bar
""");

      expect(file.span(0, 5).highlight(), equals("""
  ,
1 | / foo
2 | \\ 
  '"""));
    });
  });

  group("prints tabs as spaces", () {
    group("in a single-line span", () {
      test("before the highlighted section", () {
        var span = new SourceFile.fromString("foo\tbar baz").span(4, 7);

        expect(span.highlight(), equals("""
  ,
1 | foo    bar baz
  |        ^^^
  '"""));
      });

      test("within the highlighted section", () {
        var span = new SourceFile.fromString("foo bar\tbaz bang").span(4, 11);

        expect(span.highlight(), equals("""
  ,
1 | foo bar    baz bang
  |     ^^^^^^^^^^
  '"""));
      });

      test("after the highlighted section", () {
        var span = new SourceFile.fromString("foo bar\tbaz").span(4, 7);

        expect(span.highlight(), equals("""
  ,
1 | foo bar    baz
  |     ^^^
  '"""));
      });
    });

    group("in a multi-line span", () {
      test("before the highlighted section", () {
        var span = new SourceFile.fromString("""
foo\tbar baz
whiz bang boom
""").span(4, 21);

        expect(span.highlight(), equals("""
  ,
1 |   foo    bar baz
  | ,--------^
2 | | whiz bang boom
  | '---------^
  '"""));
      });

      test("within the first highlighted line", () {
        var span = new SourceFile.fromString("""
foo bar\tbaz
whiz bang boom
""").span(4, 21);

        expect(span.highlight(), equals("""
  ,
1 |   foo bar    baz
  | ,-----^
2 | | whiz bang boom
  | '---------^
  '"""));
      });

      test("within a middle highlighted line", () {
        var span = new SourceFile.fromString("""
foo bar baz
whiz\tbang boom
zip zap zop
""").span(4, 34);

        expect(span.highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz    bang boom
3 | | zip zap zop
  | '-------^
  '"""));
      });

      test("within the last highlighted line", () {
        var span = new SourceFile.fromString("""
foo bar baz
whiz\tbang boom
""").span(4, 21);

        expect(span.highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz    bang boom
  | '------------^
  '"""));
      });

      test("after the highlighted section", () {
        var span = new SourceFile.fromString("""
foo bar baz
whiz bang\tboom
""").span(4, 21);

        expect(span.highlight(), equals("""
  ,
1 |   foo bar baz
  | ,-----^
2 | | whiz bang    boom
  | '---------^
  '"""));
      });
    });
  });

  group("supports lines of preceding and following context for a span", () {
    test("within a single line", () {
      var span = new SourceSpanWithContext(
          new SourceLocation(20, line: 2, column: 5, sourceUrl: "foo.dart"),
          new SourceLocation(27, line: 2, column: 12, sourceUrl: "foo.dart"),
          "foo bar",
          "previous\nlines\n-----foo bar-----\nfollowing line\n");

      expect(span.highlight(), equals("""
  ,
1 | previous
2 | lines
3 | -----foo bar-----
  |      ^^^^^^^
4 | following line
  '"""));
    });

    test("covering a full line", () {
      var span = new SourceSpanWithContext(
          new SourceLocation(15, line: 2, column: 0, sourceUrl: "foo.dart"),
          new SourceLocation(33, line: 3, column: 0, sourceUrl: "foo.dart"),
          "-----foo bar-----\n",
          "previous\nlines\n-----foo bar-----\nfollowing line\n");

      expect(span.highlight(), equals("""
  ,
1 | previous
2 | lines
3 | -----foo bar-----
  | ^^^^^^^^^^^^^^^^^
4 | following line
  '"""));
    });

    test("covering multiple full lines", () {
      var span = new SourceSpanWithContext(
          new SourceLocation(15, line: 2, column: 0, sourceUrl: "foo.dart"),
          new SourceLocation(23, line: 4, column: 0, sourceUrl: "foo.dart"),
          "foo\nbar\n",
          "previous\nlines\nfoo\nbar\nfollowing line\n");

      expect(span.highlight(), equals("""
  ,
1 |   previous
2 |   lines
3 | / foo
4 | \\ bar
5 |   following line
  '"""));
    });
  });

  group("colors", () {
    test("doesn't colorize if color is false", () {
      expect(file.span(4, 7).highlight(color: false), equals("""
  ,
1 | foo bar baz
  |     ^^^
  '"""));
    });

    test("colorizes if color is true", () {
      expect(file.span(4, 7).highlight(color: true), equals("""
${colors.BLUE}  ,${colors.NONE}
${colors.BLUE}1 |${colors.NONE} foo ${colors.RED}bar${colors.NONE} baz
${colors.BLUE}  |${colors.NONE}     ${colors.RED}^^^${colors.NONE}
${colors.BLUE}  '${colors.NONE}"""));
    });

    test("uses the given color if it's passed", () {
      expect(file.span(4, 7).highlight(color: colors.YELLOW), equals("""
${colors.BLUE}  ,${colors.NONE}
${colors.BLUE}1 |${colors.NONE} foo ${colors.YELLOW}bar${colors.NONE} baz
${colors.BLUE}  |${colors.NONE}     ${colors.YELLOW}^^^${colors.NONE}
${colors.BLUE}  '${colors.NONE}"""));
    });

    test("colorizes a multiline span", () {
      expect(file.span(4, 34).highlight(color: true), equals("""
${colors.BLUE}  ,${colors.NONE}
${colors.BLUE}1 |${colors.NONE}   foo ${colors.RED}bar baz${colors.NONE}
${colors.BLUE}  |${colors.NONE} ${colors.RED},-----^${colors.NONE}
${colors.BLUE}2 |${colors.NONE} ${colors.RED}| whiz bang boom${colors.NONE}
${colors.BLUE}3 |${colors.NONE} ${colors.RED}| zip zap${colors.NONE} zop
${colors.BLUE}  |${colors.NONE} ${colors.RED}'-------^${colors.NONE}
${colors.BLUE}  '${colors.NONE}"""));
    });

    test("colorizes a multiline span that highlights full lines", () {
      expect(file.span(0, 39).highlight(color: true), equals("""
${colors.BLUE}  ,${colors.NONE}
${colors.BLUE}1 |${colors.NONE} ${colors.RED}/ foo bar baz${colors.NONE}
${colors.BLUE}2 |${colors.NONE} ${colors.RED}| whiz bang boom${colors.NONE}
${colors.BLUE}3 |${colors.NONE} ${colors.RED}\\ zip zap zop${colors.NONE}
${colors.BLUE}  '${colors.NONE}"""));
    });
  });
}
