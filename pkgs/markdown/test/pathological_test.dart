// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Inputs that used to take quadratic time or overflow the stack.
///
/// Each timing case renders pathological input of about 8 KB and of about
/// 64 KB, and compares the times. Linear parsing takes about 8 times as long on
/// the larger input; quadratic parsing takes about 64 times as long.
library;

import 'dart:math';

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

const _scale = 8;
const _smallLength = 8 * 1024;
const _largeLength = _scale * _smallLength;

/// The highest accepted ratio of the large time to the small time, scaled to
/// inputs exactly [_scale] times apart.
///
/// It sits between linear and quadratic growth, with room for timing noise.
const _maxRatio = 3 * _scale;

/// Times below this are too short to compare reliably, and fast enough to pass.
const _negligible = Duration(milliseconds: 50);

final _cases = <String, String Function(int)>{
  'emphasis runs': (n) => '*a* ' * n,
  'emphasis closers without openers': (n) => 'a_ ' * n,
  'emphasis openers without closers': (n) => '_a ' * n,
  'mismatched emphasis': (n) => '*a_ ' * n,
  'detached openersBottom': (n) => '${'*a ' * n}${'_b a**c b_ ' * n}',
  'intraword underscores': (n) => 'a_b' * n,
  'link openers without closers': (n) => '[a' * n,
  'link openers with emphasis closers': (n) => '[ a_' * n,
  'bracket and paren': (n) => '[ (](' * n,
  'nested brackets': (n) => '${'[' * n}a${']' * n}',
  'nested brackets with emphasis': (n) => '${'[' * n}${'*a' * n}${']' * n}',
  'nested full references': (n) => '${'[' * n}x${'][a]' * n}',
  'long reference link label': (n) => '[${'a' * n}][${'a' * n}]',
  'undefined footnote references': (n) => '[^2]' * n,
  'undefined footnote references with definitions': (n) {
    final defs = List.generate(n ~/ 10 + 1, (i) => '[^$i]: a\n').join();
    return '$defs\n${'[^x]' * n}';
  },
  'non-footnote brackets with footnote definitions': (n) {
    final defs = List.generate(n ~/ 10 + 1, (i) => '[^$i]: a\n').join();
    return '$defs\n${'[a]' * n}';
  },
  'image openers': (n) => '![' * n,
  'image openers before links': (n) => '${'![ ' * n}${'[a](/u) ' * n}',
  'nested images': (n) => '${'![' * n}a${']' * n}',
  'unclosed link destinations': (n) => '[a](b' * n,
  'unclosed bare link destinations': (n) => '[a]((' * n,
  'unclosed bracketed link destinations': (n) => '[a](<' * n,
  'unclosed parenthesized link titles': (n) => '[a](b (' * n,
  'unbalanced parens before link title': (n) => '[a](b( "t")' * n,
  'spaces before a star': (n) => 'a\n${' ' * n}*',
  'unmatched plain text tab and alphanum': (n) => '${' \t' * n}${'a' * n}*',
  'unmatched backticks': (n) => '`a' * n,
  'backtick runs of growing length': (n) {
    final buffer = StringBuffer();
    for (var i = 1; buffer.length < n; i++) {
      buffer.write('${'`' * i}a ');
    }
    return buffer.toString();
  },
  'unclosed autolinks': (n) => '<http://a' * n,
  'extended autolink domains': (n) => 'www._a.' * n,
  'extended autolink domains with underscores': (n) => 'www._' * n,
  'email-like domains': (n) => '${'a@b.' * n}_',
  'unclosed inline declarations': (n) => 'a ${'<!a' * n}',
  'unclosed inline comments': (n) => 'a ${'<!--a-' * n}>',
  'unclosed inline processing instructions': (n) => 'a ${'<?a' * n}>',
  'unclosed inline CDATA sections': (n) => 'a ${'<![CDATA[a' * n}>',
  'one-line HTML comment blocks': (n) => '<!-- -->\n' * n,
  'resolved nested images': (n) => '${'![x' * n}${'](/u)' * n}',
  'link openers with emphasized text': (n) => '[a *b* ' * n,
  'nested links inside emphasis': (n) => '*a ${'[b](u) ' * n}a*',
  'extended autolink domains after a paren': (n) => '(www._a.' * n,
  'extended autolink domains after a star': (n) => '*www._a.' * n,
  'extended URL autolinks with underscores': (n) => 'http://_a.' * n,
  'extended autolinks preceded by slash': (n) => '/www.a.b' * n,
  'extended autolink with interior closing parens': (n) =>
      'www.a.b/${')' * n}a)',
  'extended autolinks with trailing punctuation': (n) =>
      'www.a.b${',' * 20} ' * n,
  'table delimiter row with spaces': (n) => 'a\n${'-| ' * (n ~/ 4)}x',
  'table delimiter row with trailing spaces': (n) => 'a\n-|${' ' * n}x',
  'atx heading with spaces before text': (n) => '# ${' ' * n}a',
  'multiline unclosed link reference title': (n) => '[a]: /u "\n${'x\n' * n}',
  'multiline parenthesized link reference title': (n) => '[a]: /u\n(\n' * n,
  'indented code block with many blank lines': (n) =>
      '    a\n${'\n' * n}    b\n',
  'duplicate headings': (n) => '# a\n' * n,
};

final _deepCases = <String, String Function(int)>{
  'nested strong emphasis': (n) => '${'*a **a ' * n}b${' a** a*' * n}',
  'nested strong emphasis run': (n) => '${'**' * n}a${'**' * n}',
  'nested strong emphasis with trailing text': (n) =>
      '${'*a **a ' * n}b${' a** a*' * n} x',
  'nested strong emphasis in image alt': (n) =>
      '![${'*a **a ' * n}b${' a** a*' * n}](/u)',
  'nested blockquotes': (n) => '${'> ' * n}a',
  'nested lists': (n) => '${'* ' * n}a\n',
};

/// Returns [generate] applied to the smallest power of two that gives at least
/// [length] characters.
String _sized(String Function(int) generate, int length) {
  var n = 1;
  while (generate(n).length < length) {
    n *= 2;
  }
  return generate(n);
}

/// The fastest of three renderings of [input].
Duration _time(String input, ExtensionSet extensionSet) {
  Duration? fastest;
  for (var i = 0; i < 3; i++) {
    final stopwatch = Stopwatch()..start();
    markdownToHtml(input, extensionSet: extensionSet);
    final elapsed = stopwatch.elapsed;
    if (fastest == null || elapsed < fastest) fastest = elapsed;
  }
  return fastest!;
}

void main() {
  for (final extensionSet in [
    ExtensionSet.commonMark,
    ExtensionSet.gitHubWeb,
  ]) {
    group(extensionSet == ExtensionSet.commonMark ? 'CommonMark' : 'GFM', () {
      group('renders in linear time:', () {
        for (final MapEntry(key: name, value: generate) in _cases.entries) {
          test(name, () {
            final small = _sized(generate, _smallLength);
            final large = _sized(generate, _largeLength);
            final smallTime = _time(small, extensionSet);
            final largeTime = _time(large, extensionSet);
            if (largeTime < _negligible) return;
            final ratio =
                largeTime.inMicroseconds /
                (smallTime.inMicroseconds *
                    large.length /
                    small.length /
                    _scale);
            expect(
              ratio,
              lessThan(_maxRatio),
              reason: 'small: $smallTime, large: $largeTime',
            );
          });
        }
      });

      group('renders deep nesting without overflowing the stack:', () {
        for (final MapEntry(key: name, value: generate) in _deepCases.entries) {
          test(name, () {
            expect(
              markdownToHtml(generate(32000), extensionSet: extensionSet),
              isNotEmpty,
            );
          });
        }
      });
    });
  }

  test('a link builder that does not call getChildren', () {
    final document = Document(
      linkBuilder: (label, title, getChildren) => [Element.text('a', label)],
    );
    expect(document.parseInline('[*a*][ref]'), isNotEmpty);
  });

  test('token-alphabet fuzzer renders without hanging or crashing', () {
    const tokens = [
      '[',
      ']',
      '(',
      ')',
      '<',
      '>',
      '*',
      '_',
      '~',
      '`',
      '!',
      r'\',
      '"',
      "'",
      ':',
      '@',
      'www.',
      '<!',
      '<?',
      '<!--',
      '\n',
      ' ',
      'a',
    ];
    final random = Random(42);
    for (var i = 0; i < 200; i++) {
      final subsetSize = 2 + random.nextInt(5);
      final subset = [
        for (var j = 0; j < subsetSize; j++)
          tokens[random.nextInt(tokens.length)],
      ];
      final buffer = StringBuffer();
      for (var j = 0; j < 2000; j++) {
        buffer.write(subset[random.nextInt(subset.length)]);
      }
      final input = buffer.toString();
      final stopwatch = Stopwatch()..start();
      markdownToHtml(input, extensionSet: ExtensionSet.gitHubWeb);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason: 'Slow fuzzer case #$i with subset $subset',
      );
    }
  });
}
