// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

List<Element> _findCodes(String source) {
  final nodes = Document().parse(source);
  final found = <Element>[];
  void visit(List<Node> nodes) {
    for (final node in nodes) {
      if (node is Element) {
        if (node.tag == 'code') {
          found.add(node);
        }
        final children = node.children;
        if (children != null) visit(children);
      }
    }
  }

  visit(nodes);
  return found;
}

Element _findCode(String source) => _findCodes(source).first;

void main() {
  group('inline code span offset/length', () {
    test('is tracked for a single-line paragraph', () {
      const source = 'Just a `single` line.';
      final code = _findCode(source);
      expect(code.offset, 7);
      expect(code.length, 8);
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`single`',
      );
    });

    test('is tracked across a soft line break', () {
      const source = 'Hello `world` and\nsome `more code` here.';
      final codes = _findCodes(source);
      expect(codes, hasLength(2));

      final first = codes[0];
      expect(first.offset, 6);
      expect(first.length, 7);
      expect(
        source.substring(first.offset!, first.offset! + first.length!),
        '`world`',
      );

      // The second span isn't skipped or mis-tracked just because it's not
      // the first match in the block.
      final second = codes[1];
      expect(second.offset, 23);
      expect(second.length, 11);
      expect(
        source.substring(second.offset!, second.offset! + second.length!),
        '`more code`',
      );
    });

    test('is tracked across a line break using CRLF line endings', () {
      const source = 'Hello `world\r\nmore` text.';
      final code = _findCode(source);
      expect(code.textContent, 'world more');
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`world\r\nmore`',
      );
    });

    test('is tracked for spans delimited by multiple backticks', () {
      const source = 'A code span with `` embedded ` backtick ``.';
      final code = _findCode(source);
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`` embedded ` backtick ``',
      );
    });

    test('is null when not computable, such as inside a blockquote', () {
      const source = '> A `blockquote code` span.';
      final code = _findCode(source);
      expect(code.offset, isNull);
      expect(code.length, isNull);
    });

    test('produces no code element when a continuation line is interpreted '
        'as a new block', () {
      // The second line starts with `+ `, a valid unordered list marker,
      // so it ends the paragraph before the closing backtick is reached.
      const source = 'something `here\n+ there` like this?';
      expect(_findCodes(source), isEmpty);
      expect(
        markdownToHtml(source),
        '<p>something `here</p>\n<ul>\n<li>there` like this?</li>\n</ul>\n',
      );
    });

    test('is tracked when a continuation line is not a block marker', () {
      // Without the space after `+`, the second line is not a list marker,
      // so the paragraph (and the code span within it) stays intact.
      const source = 'something `here\n+there` like this?';
      final code = _findCode(source);
      expect(code.textContent, 'here +there');
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`here\n+there`',
      );
    });

    test('produces no code element for an unclosed backtick', () {
      const source = 'something `here with no closing backtick at all';
      expect(_findCodes(source), isEmpty);
      expect(
        markdownToHtml(source),
        '<p>something `here with no closing backtick at all</p>\n',
      );
    });

    test('ignores a backslash-escaped backtick, and still tracks a real span '
        'that follows it', () {
      const source = r'a \` and a `code` span';
      final codes = _findCodes(source);
      expect(codes, hasLength(1));
      final code = codes.single;
      expect(code.textContent, 'code');
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`code`',
      );
    });

    test('is tracked inside an atx header', () {
      const source = '## The `foo` method';
      final code = _findCode(source);
      expect(code.textContent, 'foo');
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`foo`',
      );
    });

    test('is tracked inside an atx header with extra whitespace and a '
        'closing marker', () {
      const source = '##   The `foo` method   ##';
      final code = _findCode(source);
      expect(code.textContent, 'foo');
      expect(
        source.substring(code.offset!, code.offset! + code.length!),
        '`foo`',
      );
    });

    test('is tracked for every span in a header, not just the first', () {
      const source = '# `foo` and `bar` in one header';
      final codes = _findCodes(source);
      expect(codes, hasLength(2));

      final first = codes[0];
      expect(first.textContent, 'foo');
      expect(
        source.substring(first.offset!, first.offset! + first.length!),
        '`foo`',
      );

      final second = codes[1];
      expect(second.textContent, 'bar');
      expect(
        source.substring(second.offset!, second.offset! + second.length!),
        '`bar`',
      );
    });
  });
}
