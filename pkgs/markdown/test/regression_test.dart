// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('HTML comment with dashes #2119', () {
    // See https://dartbug.com/tools/2119.
    // For this issue, the leading letter was needed,
    // an HTML comment starting a line is handled by a different path.
    // The empty line before the `-->` is needed.
    // The number of lines increase time exponentially.
    // The length of lines affect the base of the exponentiation.
    // Locally, three "Lorem-ipsum" lines ran in ~6 seconds, two in < 200 ms.
    // Adding a fourth line should ensure it cannot possibly finish in ten
    // seconds if the bug isn't fixed.
    const input = '''
a <!-- 
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
-->
''';

    final time = Stopwatch()..start();
    final html = markdownToHtml(input); // Should not hang.
    expect(html, isNotNull); // To use the output.
    final elapsed = time.elapsedMilliseconds;
    expect(elapsed, lessThan(10000));
  });

  test('HTML comment with lt/gt', () {
    // Incorrect parsing found as part of fixing #2119.
    // Now matches `<!--$text-->` where text
    // does not start with `>` or `->`, does not end with `-`,
    // and does not contain `--`.
    const input = 'a <!--<->>-<!-->';
    final html = markdownToHtml(input);
    expect(html, '<p>$input</p>\n');
  });

  test('setext heading underline is not an empty list item, GFM #2108', () {
    // See https://github.com/dart-lang/tools/issues/2108.
    // With `ExtensionSet.gitHubFlavored`, `UnorderedListWithCheckboxSyntax`
    // used to be checked before `SetextHeaderSyntax`, so a lone `-` line
    // continuing a paragraph was parsed as an empty list item instead of a
    // setext H2 underline.
    final html = markdownToHtml(
      'I am paragraph\n-',
      extensionSet: ExtensionSet.gitHubFlavored,
    );
    expect(html, '<h2>I am paragraph</h2>\n');
  });

  test('long unbroken word does not take quadratic time', () {
    // The plain-text accelerator regex required a trailing whitespace, so a
    // long run of word characters that reached the end of a line without one
    // (a single long word) forced the regex to backtrack across the whole run
    // at every position, giving quadratic parse time. A ~200k character word
    // used to take tens of seconds; it should now be effectively instant.
    final input = '${'a' * 200000}\n';

    final time = Stopwatch()..start();
    final html = markdownToHtml(input); // Should not hang.
    expect(html, isNotNull); // To use the output.
    expect(time.elapsedMilliseconds, lessThan(10000));
  });

  group('link reference definitions at EOF', () {
    test('trailing backslash in label does not throw RangeError', () {
      expect(markdownToHtml(r'[\'), '<p>[\\</p>\n');
    });

    test('trailing backslash in bracketed destination does not throw', () {
      expect(markdownToHtml(r'[a]: <\'), '<p>[a]: &lt;\\</p>\n');
    });

    test('trailing backslash in bare destination does not throw', () {
      expect(markdownToHtml(r'[a]: \'), '\n');
      expect(markdownToHtml('[a]: \\\n\n[a]'), '<p><a href="%5C">a</a></p>\n');
    });

    test('trailing backslash in title does not throw RangeError', () {
      expect(markdownToHtml(r'[a]: /url "\'), '<p>[a]: /url &quot;\\</p>\n');
    });

    test('unclosed bracketed destination at EOF does not throw RangeError', () {
      expect(markdownToHtml('[a]: <'), '<p>[a]: &lt;</p>\n');
      expect(markdownToHtml('[*#]:<'), '<p>[*#]:&lt;</p>\n');
    });

    test('unbalanced parentheses in bare destination are rejected', () {
      expect(
        markdownToHtml('[a]: /url)\n\n[a]'),
        '<p>[a]: /url)</p>\n<p>[a]</p>\n',
      );
      expect(
        markdownToHtml('[a]: /url(bar\n\n[a]'),
        '<p>[a]: /url(bar</p>\n<p>[a]</p>\n',
      );
      expect(
        markdownToHtml('[a]: /url(a)b\n\n[a]'),
        '<p><a href="/url(a)b">a</a></p>\n',
      );
    });
  });

  test('multiple non-advancing block syntaxes on the same line do not throw '
      'AssertionError', () {
    // Line 1 matches both TableSyntax.canParse (because line 2 is a 2-column
    // table delimiter row) and LinkReferenceDefinitionSyntax.canParse, and
    // both retreat to line 1 during parse().
    const input = '[a]: /b (c\n| :--- | ---: |\n';
    expect(
      markdownToHtml(input, extensionSet: ExtensionSet.gitHubFlavored),
      '<p>[a]: /b (c\n| :--- | ---: |</p>\n',
    );
  });

  test('footnote definition containing a list or horizontal rule does not '
      'throw TypeError', () {
    expect(
      markdownToHtml(
        '[^1]\n\n[^1]: - note',
        extensionSet: ExtensionSet.gitHubWeb,
      ),
      '<p><sup class="footnote-ref"><a href="#fn-1" id="fnref-1">1</a></sup></p>\n'
      '<section class="footnotes">\n'
      '<ol>\n'
      '<li id="fn-1">\n'
      '<ul>\n'
      '<li>note</li><a href="#fnref-1" class="footnote-backref">\u21a9</a></ul>\n'
      '</li>\n'
      '</ol>\n'
      '</section>\n',
    );
    expect(
      markdownToHtml('[^1]\n\n[^1]: ---', extensionSet: ExtensionSet.gitHubWeb),
      '<p><sup class="footnote-ref"><a href="#fn-1" id="fnref-1">1</a></sup></p>\n'
      '<section class="footnotes">\n'
      '<ol>\n'
      '<li id="fn-1">\n'
      '<hr /> <a href="#fnref-1" class="footnote-backref">\u21a9</a></li>\n'
      '</ol>\n'
      '</section>\n',
    );
  });

  test(
    'many consecutive link reference definitions do not re-read later lines',
    () {
      // LinkReferenceDefinitionSyntax used to consume every remaining line in
      // the block (because LinkReferenceDefinitionSyntax.canEndBlock is false),
      // join them with '\n', parse a single definition, split the unconsumed
      // remainder on '\n', and retreat BlockParser by that count. For N
      // consecutive definitions, line k had its content read O(k) times.
      const count = 100;
      final lines = [
        for (var i = 1; i <= count; i++)
          _CountingLine('[#$i]: https://example.com/pull/$i'),
        _CountingLine(''),
        _CountingLine('See [#1] and [#$count].'),
      ];

      final html = renderToHtml(Document().parseLineList(lines));
      expect(
        html,
        '<p>See <a href="https://example.com/pull/1">#1</a> and '
        '<a href="https://example.com/pull/$count">#$count</a>.</p>',
      );
      for (final line in lines) {
        expect(line.reads, lessThan(20));
      }
    },
  );

  group('inline syntaxes that check their first character', () {
    // These syntaxes skip the regex when the first character cannot match.
    // They must still match after CJK text and punctuation, and leave a lone
    // first character as text.
    test('EmojiSyntax', () {
      expect(
        markdownToHtml(
          '中文:smile: a: b, (:+1:)',
          inlineSyntaxes: [EmojiSyntax()],
        ),
        '<p>中文😄 a: b, (👍)</p>\n',
      );
    });

    test('AutolinkSyntax', () {
      expect(
        markdownToHtml('中文<http://a.b>, (<mailto:x@y.z>) a < b'),
        '<p>中文<a href="http://a.b">http://a.b</a>, '
        '(<a href="mailto:x@y.z">mailto:x@y.z</a>) a &lt; b</p>\n',
      );
    });

    test('CodeSyntax', () {
      expect(
        markdownToHtml('中文`code`, (``a`b``) a ` b'),
        '<p>中文<code>code</code>, (<code>a`b</code>) a ` b</p>\n',
      );
    });

    test('ColorSwatchSyntax', () {
      expect(
        markdownToHtml(
          '中文`#f00`, (`rgb(0,255,0)`) `#ba`',
          inlineSyntaxes: [ColorSwatchSyntax()],
        ),
        '<p>中文<code class="gfm-color_chip">#f00<span '
        'style="background-color:#f00;"></span></code>, '
        '(<code class="gfm-color_chip">rgb(0,255,0)<span '
        'style="background-color:rgb(0,255,0);"></span></code>) '
        '<code>#ba</code></p>\n',
      );
    });
  });

  test('linkBuilder that does not call getChildren discards inner nodes', () {
    expect(
      markdownToHtml(
        'hello [a]',
        linkBuilder: (label, title, getChildren) => [Element.text('a', label)],
      ),
      '<p>hello <a>a</a></p>\n',
    );
  });

  test('reusing HtmlRenderer resets duplicate heading ID suffixes', () {
    final doc = Document(extensionSet: ExtensionSet.gitHubWeb);
    final nodes = doc.parseLines(['# a', '# a', '# a']);
    final renderer = HtmlRenderer();
    const expected =
        '<h1 id="a">a</h1>\n<h1 id="a-2">a</h1>\n<h1 id="a-3">a</h1>';
    expect(renderer.render(nodes), expected);
    expect(renderer.render(nodes), expected);
  });

  test('container block nesting depth is capped at 100', () {
    expect(markdownToHtml('${'> ' * 101}a'), isNotEmpty);
  });
}

class _CountingLine extends Line {
  int reads = 0;

  _CountingLine(super.content);

  @override
  String get content {
    reads++;
    return super.content;
  }
}
