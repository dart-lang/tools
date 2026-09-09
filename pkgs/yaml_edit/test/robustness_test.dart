// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/char_codes.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('YamlChar constants and predicates', () {
    test('constants have correct ASCII code units', () {
      expect(YamlChar.tab, equals(0x09));
      expect(YamlChar.lineFeed, equals(0x0A));
      expect(YamlChar.carriageReturn, equals(0x0D));
      expect(YamlChar.space, equals(0x20));
      expect(YamlChar.hash, equals(0x23));
      expect(YamlChar.asterisk, equals(0x2A));
      expect(YamlChar.comma, equals(0x2C));
      expect(YamlChar.hyphen, equals(0x2D));
      expect(YamlChar.colon, equals(0x3A));
      expect(YamlChar.question, equals(0x3F));
      expect(YamlChar.leftSquare, equals(0x5B));
      expect(YamlChar.rightSquare, equals(0x5D));
      expect(YamlChar.leftCurly, equals(0x7B));
      expect(YamlChar.rightCurly, equals(0x7D));
    });

    test('isWhitespace', () {
      expect(YamlChar.isWhitespace(0x20), isTrue);
      expect(YamlChar.isWhitespace(0x09), isTrue);
      expect(YamlChar.isWhitespace(0x0A), isFalse);
      expect(YamlChar.isWhitespace(0x0D), isFalse);
      expect(YamlChar.isWhitespace(0x61), isFalse); // 'a'
      expect(YamlChar.isWhitespace(-1), isFalse);
    });

    test('isLineBreak', () {
      expect(YamlChar.isLineBreak(0x0A), isTrue);
      expect(YamlChar.isLineBreak(0x0D), isTrue);
      expect(YamlChar.isLineBreak(0x20), isFalse);
      expect(YamlChar.isLineBreak(0x09), isFalse);
      expect(YamlChar.isLineBreak(0x61), isFalse);
      expect(YamlChar.isLineBreak(-1), isFalse);
    });

    test('isFlowIndicator', () {
      expect(YamlChar.isFlowIndicator(0x2C), isTrue); // ','
      expect(YamlChar.isFlowIndicator(0x5B), isTrue); // '['
      expect(YamlChar.isFlowIndicator(0x5D), isTrue); // ']'
      expect(YamlChar.isFlowIndicator(0x7B), isTrue); // '{'
      expect(YamlChar.isFlowIndicator(0x7D), isTrue); // '}'
      expect(YamlChar.isFlowIndicator(0x20), isFalse);
      expect(YamlChar.isFlowIndicator(0x3A), isFalse); // ':'
      expect(YamlChar.isFlowIndicator(0x2D), isFalse); // '-'
      expect(YamlChar.isFlowIndicator(-1), isFalse);
    });

    test('isAnchorChar', () {
      // Valid anchor chars
      expect(YamlChar.isAnchorChar(0x61), isTrue); // 'a'
      expect(YamlChar.isAnchorChar(0x30), isTrue); // '0'
      expect(YamlChar.isAnchorChar(0x2E), isTrue); // '.'
      expect(YamlChar.isAnchorChar(0x2F), isTrue); // '/'
      expect(YamlChar.isAnchorChar(0x40), isTrue); // '@'
      expect(YamlChar.isAnchorChar(0x2B), isTrue); // '+'
      expect(YamlChar.isAnchorChar(0x5F), isTrue); // '_'
      expect(YamlChar.isAnchorChar(0x2D), isTrue); // '-'

      // Invalid anchor chars: whitespace, line breaks, flow indicators
      expect(YamlChar.isAnchorChar(0x20), isFalse); // space
      expect(YamlChar.isAnchorChar(0x09), isFalse); // tab
      expect(YamlChar.isAnchorChar(0x0A), isFalse); // LF
      expect(YamlChar.isAnchorChar(0x0D), isFalse); // CR
      expect(YamlChar.isAnchorChar(0x2C), isFalse); // ','
      expect(YamlChar.isAnchorChar(0x5B), isFalse); // '['
      expect(YamlChar.isAnchorChar(0x5D), isFalse); // ']'
      expect(YamlChar.isAnchorChar(0x7B), isFalse); // '{'
      expect(YamlChar.isAnchorChar(0x7D), isFalse); // '}'
    });
  });

  group('findNextFlowDelimiter and findPreviousFlowDelimiter', () {
    test('returns -1 on empty yaml or out-of-bounds offsets', () {
      expect(
        findNextFlowDelimiter('', 0, delimiters: {YamlChar.comma}),
        equals(-1),
      );
      expect(
        findNextFlowDelimiter('abc', 5, delimiters: {YamlChar.comma}),
        equals(-1),
      );
      expect(
        findNextFlowDelimiter('abc', -2, delimiters: {YamlChar.comma}),
        equals(-1),
      );

      expect(
        findPreviousFlowDelimiter('', 0, delimiters: {YamlChar.comma}),
        equals(-1),
      );
      expect(
        findPreviousFlowDelimiter('abc', -1, delimiters: {YamlChar.comma}),
        equals(-1),
      );
      expect(
        findPreviousFlowDelimiter('a,b', 10, delimiters: {YamlChar.comma}),
        equals(1),
      );
    });

    test('findNextFlowDelimiter finds delimiter without comments', () {
      final yaml = '[1, 2, 3]';
      expect(
        findNextFlowDelimiter(yaml, 0, delimiters: {YamlChar.comma}),
        equals(2),
      );
      expect(
        findNextFlowDelimiter(yaml, 3, delimiters: {YamlChar.comma}),
        equals(5),
      );
      expect(
        findNextFlowDelimiter(yaml, 6, delimiters: {YamlChar.rightSquare}),
        equals(8),
      );
      expect(
        findNextFlowDelimiter(yaml, 6, delimiters: {YamlChar.colon}),
        equals(-1),
      );
    });

    test('findNextFlowDelimiter skips comments containing delimiters', () {
      final yaml = '[1, # comment with , and ] and }\n 2]';
      expect(
        findNextFlowDelimiter(yaml, 3, delimiters: {YamlChar.comma}),
        equals(-1),
      );
      expect(
        findNextFlowDelimiter(yaml, 3, delimiters: {YamlChar.rightSquare}),
        equals(35),
      );
    });

    test('findPreviousFlowDelimiter finds delimiter without comments', () {
      final yaml = '{a: 1, b: 2}';
      expect(
        findPreviousFlowDelimiter(yaml, 10, delimiters: {YamlChar.comma}),
        equals(5),
      );
      expect(
        findPreviousFlowDelimiter(yaml, 4, delimiters: {YamlChar.leftCurly}),
        equals(0),
      );
      expect(
        findPreviousFlowDelimiter(yaml, 4, delimiters: {YamlChar.rightCurly}),
        equals(-1),
      );
    });

    test('findPreviousFlowDelimiter skips comments containing delimiters', () {
      final yaml = '{\n  a: 1, # comment with , and { and }\n  b: 2\n}';
      // Search from before 'b'
      final bOffset = yaml.indexOf('b:');
      final found = findPreviousFlowDelimiter(
        yaml,
        bOffset,
        delimiters: {YamlChar.comma},
      );
      expect(found, equals(yaml.indexOf(',')));
    });

    test('findPreviousFlowDelimiter with multiple comment lines', () {
      final yaml = '[\n'
          '  1,\n'
          '  # comment line 1 with ,\n'
          '  # comment line 2 with ,\n'
          '  2\n'
          ']';
      final twoOffset = yaml.indexOf('2');
      final found = findPreviousFlowDelimiter(
        yaml,
        twoOffset,
        delimiters: {YamlChar.comma},
      );
      expect(found, equals(yaml.indexOf(',')));
    });

    test('findPreviousFlowDelimiter with CR and CRLF line endings', () {
      final yamlCr = '[\r  1,\r  # comment with ,\r  2\r]';
      final twoCr = yamlCr.indexOf('2');
      expect(
        findPreviousFlowDelimiter(yamlCr, twoCr, delimiters: {YamlChar.comma}),
        equals(yamlCr.indexOf(',')),
      );

      final yamlCrlf = '[\r\n  1,\r\n  # comment with ,\r\n  2\r\n]';
      final twoCrlf = yamlCrlf.indexOf('2');
      expect(
        findPreviousFlowDelimiter(
          yamlCrlf,
          twoCrlf,
          delimiters: {YamlChar.comma},
        ),
        equals(yamlCrlf.indexOf(',')),
      );
    });

    test('findPreviousFlowDelimiter when search starts inside comment', () {
      final yaml = '[ 1, # inside comment with , here ]';
      final insideComment = yaml.indexOf('here');
      final found = findPreviousFlowDelimiter(
        yaml,
        insideComment,
        delimiters: {YamlChar.comma},
      );
      expect(found, equals(yaml.indexOf(',')));
    });

    test('findPreviousFlowDelimiter when comment is at start of line', () {
      final yaml = '1,\n# comment with ,\n2';
      final found = findPreviousFlowDelimiter(
        yaml,
        yaml.indexOf('2'),
        delimiters: {YamlChar.comma},
      );
      expect(found, equals(yaml.indexOf(',')));
    });
  });

  group('aliasReferencePattern', () {
    test('matches alias references accurately with special characters', () {
      final pattern = aliasReferencePattern('a.b/c@d+1');
      expect(pattern.hasMatch('*a.b/c@d+1'), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1,'), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1]'), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1}'), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1\n'), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1 '), isTrue);
      expect(pattern.hasMatch('*a.b/c@d+1\t'), isTrue);

      // Positive lookahead prevents matching prefixes of longer anchor names
      expect(pattern.hasMatch('*a.b/c@d+1_extra'), isFalse);
      expect(pattern.hasMatch('*a.b/c@d+1.more'), isFalse);
      expect(pattern.hasMatch('*a.b/c@d+1/sub'), isFalse);
    });

    test('matches with leading whitespace when requested', () {
      final withWs =
          aliasReferencePattern('ref', includeLeadingWhitespace: true);
      expect(withWs.hasMatch('  *ref'), isTrue);
      expect(withWs.hasMatch('\t*ref'), isTrue);
      expect(withWs.firstMatch('  *ref')!.group(0), equals('  *ref'));

      final withoutWs = aliasReferencePattern('ref');
      expect(withoutWs.firstMatch('  *ref')!.group(0), equals('*ref'));
    });
  });

  group('Anchor names with ., /, @, + and intra-template aliases', () {
    test('copyOnWrite unfolding with dots, slashes, at, plus in anchor names',
        () {
      final doc = YamlEditor(
        '''
template: &tmpl.v1/prod@main+build
  config:
    url: https://example.com
    port: 8080
service: *tmpl.v1/prod@main+build
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['service', 'config', 'port'], 9090);
      expect(doc.toString(), equals('''
template: &tmpl.v1/prod@main+build
  config:
    url: https://example.com
    port: 8080
service:
  config:
    url: https://example.com
    port: 9090
'''));
      expect(doc.parseAt(['template', 'config', 'port']).value, equals(8080));
      expect(doc.parseAt(['service', 'config', 'port']).value, equals(9090));
    });

    test('nested intra-template aliases with prefix names are sorted correctly',
        () {
      final doc = YamlEditor(
        '''
tmpl: &t
  sub_long: &prefix_long 100
  sub_short: &prefix 200
  use_short: *prefix
  use_long: *prefix_long
copy: *t
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['copy', 'use_short'], 999);
      final result = doc.toString();
      expect(result, contains('use_long: 100'));
      expect(result, contains('use_short: 999'));
      expect(doc.parseAt(['copy', 'use_long']).value, equals(100));
      expect(doc.parseAt(['copy', 'use_short']).value, equals(999));
      expect(doc.parseAt(['tmpl', 'use_long']).value, equals(100));
      expect(doc.parseAt(['tmpl', 'use_short']).value, equals(200));
    });

    test('nested intra-template aliases with dots and slashes prefix names',
        () {
      final doc = YamlEditor(
        '''
tmpl: &root
  short: &a.b 1
  longer: &a.b.c 2
  slash_short: &x/y 3
  slash_longer: &x/y/z 4
  ref_short: *a.b
  ref_longer: *a.b.c
  ref_slash_short: *x/y
  ref_slash_longer: *x/y/z
dest: *root
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.update(['dest', 'ref_short'], 111);
      final result = doc.toString();
      expect(result, contains('ref_short: 111'));
      expect(result, contains('ref_longer: 2'));
      expect(result, contains('ref_slash_short: 3'));
      expect(result, contains('ref_slash_longer: 4'));
    });
  });

  group('Appending to block list ending with alias reference', () {
    test('appends to list end rather than anchor definition', () {
      final doc = YamlEditor(
        '''
anchors:
  def: &target 42
items:
  - 1
  - *target
''',
        aliasBehavior: AliasBehavior.reference,
      );

      doc.appendToList(['items'], 99);
      expect(doc.toString(), equals('''
anchors:
  def: &target 42
items:
  - 1
  - *target
  - 99
'''));
      expect(doc.parseAt(['items', 0]).value, equals(1));
      expect(doc.parseAt(['items', 1]).value, equals(42));
      expect(doc.parseAt(['items', 2]).value, equals(99));
      expect(doc.parseAt(['anchors', 'def']).value, equals(42));
    });

    test('appends to block list ending with alias reference in copyOnWrite',
        () {
      final doc = YamlEditor(
        '''
anchors:
  def: &target val
items:
  - *target
''',
        aliasBehavior: AliasBehavior.copyOnWrite,
      );

      doc.appendToList(['items'], 'added');
      expect(doc.toString(), equals('''
anchors:
  def: &target val
items:
  - *target
  - added
'''));
    });
  });

  group('Quoted map keys with spaces before colon', () {
    test('preserves colon when updating double-quoted key with space', () {
      final doc = YamlEditor('''
"key" : 123
other: 456
''');
      doc.update(['key'], 789);
      expect(doc.toString(), equals('''
"key" : 789
other: 456
'''));
      expect(doc.parseAt(['key']).value, equals(789));
    });

    test('preserves colon when updating single-quoted key with space', () {
      final doc = YamlEditor('''
'my quoted key'   : 100
''');
      doc.update(['my quoted key'], 200);
      expect(doc.toString(), equals('''
'my quoted key'   : 200
'''));
      expect(doc.parseAt(['my quoted key']).value, equals(200));
    });

    test('preserves colon when replacing with block collection', () {
      final doc = YamlEditor('''
"key"  : 123
''');
      doc.update(['key'], ['a', 'b']);
      expect(doc.toString(), equals('''
"key"  :
  - a
  - b
'''));
      expect(doc.parseAt(['key', 0]).value, equals('a'));
    });
  });

  group('Flow collections with comments containing delimiters', () {
    test('insert into flow list with comment containing comma and brackets',
        () {
      final doc = YamlEditor('[1, # comment with , and [ and ]\n 2]');
      doc.insertIntoList([], 1, 'inserted');
      expect(doc.parseAt([0]).value, equals(1));
      expect(doc.parseAt([1]).value, equals('inserted'));
      expect(doc.parseAt([2]).value, equals(2));
    });

    test('update flow list with comment containing comma and bracket', () {
      final doc = YamlEditor('[1 # comment with , and ]\n, 2]');
      doc.update([0], 'updated');
      expect(doc.parseAt([0]).value, equals('updated'));
      expect(doc.parseAt([1]).value, equals(2));
    });

    test('remove from flow list with comments containing delimiters', () {
      // Remove first element
      final doc1 = YamlEditor('[1 # comment with , and ]\n, 2]');
      doc1.remove([0]);
      expect(doc1.parseAt([0]).value, equals(2));

      // Remove last element
      final doc2 = YamlEditor('[1, # comment with , and ]\n 2]');
      doc2.remove([1]);
      expect(doc2.parseAt([0]).value, equals(1));

      // Remove single element with comment
      final doc3 = YamlEditor('[ 1 # comment with ]\n]');
      doc3.remove([0]);
      expect(doc3.toString(), equals('[]'));
      expect(doc3.parseAt([]).value, equals([]));
    });

    test('flow map update with comment containing comma and braces', () {
      final doc = YamlEditor('{a: 1 # comment with , and { and }\n, b: 2}');
      doc.update(['a'], 99);
      expect(doc.parseAt(['a']).value, equals(99));
      expect(doc.parseAt(['b']).value, equals(2));

      doc.update(['b'], 88);
      expect(doc.parseAt(['b']).value, equals(88));
    });

    test('flow map insert with comment containing delimiters', () {
      final doc = YamlEditor('{a: 1 # comment with , and }\n, b: 2}');
      doc.update(['c'], 3);
      expect(doc.parseAt(['a']).value, equals(1));
      expect(doc.parseAt(['b']).value, equals(2));
      expect(doc.parseAt(['c']).value, equals(3));
    });

    test('flow map remove first entry with comment containing comma and brace',
        () {
      final doc1 = YamlEditor('{a: 1 # comment with , and }\n, b: 2}');
      doc1.remove(['a']);
      expect(doc1.parseAt(['b']).value, equals(2));

      // Remove non-first entry with comment preceding it
      final doc2 = YamlEditor('{b: 2, # comment with , and }\n a: 1}');
      doc2.remove(['a']);
      expect(doc2.parseAt(['b']).value, equals(2));

      // Remove single entry with comment
      final doc3 = YamlEditor('{a: 1 # comment with }\n}');
      doc3.remove(['a']);
      expect(doc3.toString(), equals('{}'));
      expect(doc3.parseAt([]).value, equals({}));
    });

    test('flow map update empty value without space after colon', () {
      final doc = YamlEditor('{a:}');
      doc.update(['a'], 'hello');
      expect(doc.toString(), equals('{a: hello}'));
      expect(doc.parseAt(['a']).value, equals('hello'));
    });

    test('flow map update empty value with comment', () {
      final doc = YamlEditor('{a: # comment\n, b: 1}');
      doc.update(['a'], 'hello');
      expect(doc.parseAt(['a']).value, equals('hello'));
      expect(doc.parseAt(['b']).value, equals(1));
    });
  });

  group('Appending to block list ending with keep-chomping scalar (|+)', () {
    test('preserves trailing newlines of |+ when appending', () {
      final doc = YamlEditor('list:\n  - |+\n    hello\n');
      doc.appendToList(['list'], 'next');
      final result = doc.toString();
      expect(result, equals('list:\n  - |+\n    hello\n  - next\n'));
      expect(doc.parseAt(['list', 0]).value, equals('hello\n'));
      expect(doc.parseAt(['list', 1]).value, equals('next'));
    });

    test('appends to list ending with single-line scalar without newlines', () {
      final doc = YamlEditor('list:\n  - item');
      doc.appendToList(['list'], 'item2');
      expect(doc.parseAt(['list', 0]).value, equals('item'));
      expect(doc.parseAt(['list', 1]).value, equals('item2'));
    });
  });

  group('Literal and folded block scalar encoding with CRLF', () {
    test('literal block scalar encodes with CRLF header', () {
      final doc = YamlEditor('key: initial\r\nother: 1\r\n');
      doc.update(
        ['key'],
        wrapAsYamlNode('line1\nline2', scalarStyle: ScalarStyle.LITERAL),
      );
      final result = doc.toString();
      expect(result, contains('|-\r\n'));
      expect(result, isNot(contains('|-\n ')));
      expect(doc.parseAt(['key']).value, equals('line1\nline2'));
    });

    test('folded block scalar encodes with CRLF header', () {
      final doc = YamlEditor('key: initial\r\nother: 1\r\n');
      doc.update(
        ['key'],
        wrapAsYamlNode('line1\nline2', scalarStyle: ScalarStyle.FOLDED),
      );
      final result = doc.toString();
      expect(result, contains('>-\r\n'));
      expect(doc.parseAt(['key']).value, equals('line1\nline2'));
    });
  });

  group('getListIndentation with alias references', () {
    test('block list with only aliases falls back to list.span.start.column',
        () {
      final yaml = '''
anchors:
  a: &item1 10
  b: &item2 20
list:
  - *item1
  - *item2
''';
      final doc = YamlEditor(yaml);
      final list = doc.parseAt(['list']) as YamlList;
      final indent = getListIndentation(yaml, list);
      expect(indent, equals(2));
    });

    test('nested block list with only aliases preserves indent column', () {
      final yaml = '''
anchors:
  val: &v 1
data:
  nested:
    - *v
''';
      final doc = YamlEditor(yaml);
      final list = doc.parseAt(['data', 'nested']) as YamlList;
      final indent = getListIndentation(yaml, list);
      expect(indent, equals(4));
    });

    test('flow list returns 0', () {
      final yaml = '[1, 2, 3]';
      final doc = YamlEditor(yaml);
      final list = doc.parseAt([]) as YamlList;
      expect(getListIndentation(yaml, list), equals(0));
    });

    test('empty block list throws UnsupportedError', () {
      final emptyBlockList =
          YamlList.internal([], shellSpan(null), CollectionStyle.BLOCK);
      expect(
        () => getListIndentation('', emptyBlockList),
        throwsUnsupportedError,
      );
    });
  });
}
