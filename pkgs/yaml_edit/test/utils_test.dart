// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/char_codes.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  group('indentation', () {
    test('returns 2 for empty strings', () {
      final doc = YamlEditor('');
      expect(getIndentation(doc), equals(2));
    });

    test('returns 2 for strings consisting only scalars', () {
      final doc = YamlEditor('foo');
      expect(getIndentation(doc), equals(2));
    });

    test('returns 2 if only top-level elements are present', () {
      final doc = YamlEditor('''
- 1
- 2
- 3''');
      expect(getIndentation(doc), equals(2));
    });

    test('detects the indentation used in nested list', () {
      final doc = YamlEditor('''
- 1
- 2
- 
   - 3
   - 4''');
      expect(getIndentation(doc), equals(3));
    });

    test('detects the indentation used in nested map', () {
      final doc = YamlEditor('''
a: 1
b: 2
c:
   d: 4
   e: 5''');
      expect(getIndentation(doc), equals(3));
    });

    test('detects the indentation used in nested map in list', () {
      final doc = YamlEditor('''
- 1
- 2
- 
    d: 4
    e: 5''');
      expect(getIndentation(doc), equals(4));
    });

    test('detects the indentation used in nested map in list with complex keys',
        () {
      final doc = YamlEditor('''
- 1
- 2
- 
    ? d
    : 4''');
      expect(getIndentation(doc), equals(4));
    });

    test('detects the indentation used in nested list in map', () {
      final doc = YamlEditor('''
a: 1
b: 2
c:
  - 4
  - 5''');
      expect(getIndentation(doc), equals(2));
    });
  });

  group('styling options', () {
    group('update', () {
      test('flow map with style', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(['YAML'],
            wrapAsYamlNode('hi', scalarStyle: ScalarStyle.DOUBLE_QUOTED));

        expect(doc.toString(), equals('{YAML: "hi"}'));
        expectYamlBuilderValue(doc, {'YAML': 'hi'});
      });

      test('prevents block scalars in flow map', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(
            ['YAML'], wrapAsYamlNode('test', scalarStyle: ScalarStyle.FOLDED));

        expect(doc.toString(), equals('{YAML: test}'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('wraps string in double-quotes if it contains dangerous characters',
          () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.update(
            ['YAML'], wrapAsYamlNode('> test', scalarStyle: ScalarStyle.PLAIN));

        expect(doc.toString(), equals('{YAML: "> test"}'));
        expectYamlBuilderValue(doc, {'YAML': '> test'});
      });

      test('list in map', () {
        final doc = YamlEditor('''YAML: YAML Ain't Markup Language''');
        doc.update(['YAML'],
            wrapAsYamlNode([1, 2, 3], collectionStyle: CollectionStyle.FLOW));

        expect(doc.toString(), equals('YAML: [1, 2, 3]'));
        expectYamlBuilderValue(doc, {
          'YAML': [1, 2, 3]
        });
      });

      test('nested map', () {
        final doc = YamlEditor('''YAML: YAML Ain't Markup Language''');
        doc.update(
            ['YAML'],
            wrapAsYamlNode({'YAML': "YAML Ain't Markup Language"},
                collectionStyle: CollectionStyle.FLOW));

        expect(
            doc.toString(), equals("YAML: {YAML: YAML Ain't Markup Language}"));
        expectYamlBuilderValue(doc, {
          'YAML': {'YAML': "YAML Ain't Markup Language"}
        });
      });

      test('nested list', () {
        final doc = YamlEditor('- 0');
        doc.update(
            [0],
            wrapAsYamlNode([
              1,
              2,
              wrapAsYamlNode([3, 4], collectionStyle: CollectionStyle.FLOW),
              5
            ]));

        expect(doc.toString(), equals('''
- - 1
  - 2
  - [3, 4]
  - 5'''));
        expectYamlBuilderValue(doc, [
          [
            1,
            2,
            [3, 4],
            5
          ]
        ]);
      });

      test('different scalars in block list!', () {
        final doc = YamlEditor('- 0');
        doc.update(
            [0],
            wrapAsYamlNode([
              wrapAsYamlNode('plain string', scalarStyle: ScalarStyle.PLAIN),
              wrapAsYamlNode('folded string', scalarStyle: ScalarStyle.FOLDED),
              wrapAsYamlNode('single-quoted string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              wrapAsYamlNode('literal string',
                  scalarStyle: ScalarStyle.LITERAL),
              wrapAsYamlNode('double-quoted string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            ]));

        expect(doc.toString(), equals('''
- - plain string
  - >-
      folded string
  - 'single-quoted string'
  - |-
      literal string
  - "double-quoted string"'''));
        expectYamlBuilderValue(doc, [
          [
            'plain string',
            'folded string',
            'single-quoted string',
            'literal string',
            'double-quoted string',
          ]
        ]);
      });

      test('different scalars in block map!', () {
        final doc = YamlEditor('strings: strings');
        doc.update(
            ['strings'],
            wrapAsYamlNode({
              'plain': wrapAsYamlNode('string', scalarStyle: ScalarStyle.PLAIN),
              'folded':
                  wrapAsYamlNode('string', scalarStyle: ScalarStyle.FOLDED),
              'single-quoted': wrapAsYamlNode('string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              'literal':
                  wrapAsYamlNode('string', scalarStyle: ScalarStyle.LITERAL),
              'double-quoted': wrapAsYamlNode('string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            }));

        expect(doc.toString(), equals('''
strings:
  plain: string
  folded: >-
      string
  single-quoted: 'string'
  literal: |-
      string
  double-quoted: "string"'''));
        expectYamlBuilderValue(doc, {
          'strings': {
            'plain': 'string',
            'folded': 'string',
            'single-quoted': 'string',
            'literal': 'string',
            'double-quoted': 'string',
          }
        });
      });

      test('different scalars in flow list!', () {
        final doc = YamlEditor('[0]');
        doc.update(
            [0],
            wrapAsYamlNode([
              wrapAsYamlNode('plain string', scalarStyle: ScalarStyle.PLAIN),
              wrapAsYamlNode('folded string', scalarStyle: ScalarStyle.FOLDED),
              wrapAsYamlNode('single-quoted string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              wrapAsYamlNode('literal string',
                  scalarStyle: ScalarStyle.LITERAL),
              wrapAsYamlNode('double-quoted string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            ]));

        expect(
          doc.toString(),
          equals(
            '[[plain string, folded string, \'single-quoted string\', '
            'literal string, "double-quoted string"]]',
          ),
        );
        expectYamlBuilderValue(doc, [
          [
            'plain string',
            'folded string',
            'single-quoted string',
            'literal string',
            'double-quoted string',
          ]
        ]);
      });

      test('wraps non-printable strings in double-quotes in flow context', () {
        final doc = YamlEditor('[0]');
        doc.update([0], '\x00\x07\x08\x0b\x0c\x0d\x1b\x85\xa0\u2028\u2029"');
        expect(
            doc.toString(), equals('["\\0\\a\\b\\v\\f\\r\\e\\N\\_\\L\\P\\""]'));
        expectYamlBuilderValue(
            doc, ['\x00\x07\x08\x0b\x0c\x0d\x1b\x85\xa0\u2028\u2029"']);
      });

      test('wraps non-printable strings in double-quotes in block context', () {
        final doc = YamlEditor('- 0');
        doc.update([0], '\x00\x07\x08\x0b\x0c\x0d\x1b\x85\xa0\u2028\u2029"');
        expect(
            doc.toString(), equals('- "\\0\\a\\b\\v\\f\\r\\e\\N\\_\\L\\P\\""'));
        expectYamlBuilderValue(
            doc, ['\x00\x07\x08\x0b\x0c\x0d\x1b\x85\xa0\u2028\u2029"']);
      });

      test('generates folded strings properly', () {
        final doc = YamlEditor('');
        doc.update(
            [], wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.FOLDED));
        expect(doc.toString(), equals('>-\n  test\n\n  test'));
      });

      test('rewrites folded strings properly', () {
        final doc = YamlEditor('''
- >
    folded string
''');
        doc.update(
            [0], wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.FOLDED));
        expect(doc.toString(), equals('''
- >-
    test

    test
'''));
      });

      test('rewrites folded strings properly (1)', () {
        final doc = YamlEditor('''
- >
    folded string''');
        doc.update(
            [0], wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.FOLDED));
        expect(doc.toString(), equals('''
- >-
    test

    test'''));
      });

      test('generates literal strings properly', () {
        final doc = YamlEditor('');
        doc.update(
            [], wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.LITERAL));
        expect(doc.toString(), equals('|-\n  test\n  test'));
      });

      test('rewrites literal strings properly', () {
        final doc = YamlEditor('''
- |
    literal string
''');
        doc.update([0],
            wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.LITERAL));
        expect(doc.toString(), equals('''
- |-
    test
    test
'''));
      });

      test('prevents literal strings in flow maps, even if nested', () {
        final doc = YamlEditor('''
{1: 1}
''');
        doc.update([
          1
        ], [
          wrapAsYamlNode('d9]zH`FoYC/>]', scalarStyle: ScalarStyle.LITERAL)
        ]);

        expect(doc.toString(), equals('''
{1: ["d9]zH`FoYC\\/>]"]}
'''));
        expect((doc.parseAt([1, 0]) as YamlScalar).style,
            equals(ScalarStyle.DOUBLE_QUOTED));
      });

      test('prevents literal empty strings', () {
        final doc = YamlEditor('''
a:
  c: 1
''');
        doc.update([
          'a'
        ], {
          'f': wrapAsYamlNode('', scalarStyle: ScalarStyle.LITERAL),
          'g': 1
        });

        expect(doc.toString(), equals('''
a:
  f: ""
  g: 1
'''));
      });

      test('prevents literal strings with leading spaces', () {
        final doc = YamlEditor('''
a:
  c: 1
''');
        doc.update([
          'a'
        ], {
          'f': wrapAsYamlNode(' a', scalarStyle: ScalarStyle.LITERAL),
          'g': 1
        });

        expect(doc.toString(), equals('''
a:
  f: " a"
  g: 1
'''));
      });

      test(
          'flow collection structure does not get substringed when added to '
          'block structure', () {
        final doc = YamlEditor('''
a:
  - false
''');
        doc.prependToList(['a'],
            wrapAsYamlNode([1234], collectionStyle: CollectionStyle.FLOW));
        expect(doc.toString(), equals('''
a:
  - [1234]
  - false
'''));
        expectYamlBuilderValue(doc, {
          'a': [
            [1234],
            false
          ]
        });
      });
    });
  });

  group('assertValidScalar', () {
    test('does nothing with a boolean', () {
      expect(() => assertValidScalar(true), returnsNormally);
    });

    test('does nothing with a number', () {
      expect(() => assertValidScalar(1.12), returnsNormally);
    });
    test('does nothing with infinity', () {
      expect(() => assertValidScalar(double.infinity), returnsNormally);
    });
    test('does nothing with a String', () {
      expect(() => assertValidScalar('test'), returnsNormally);
    });

    test('does nothing with null', () {
      expect(() => assertValidScalar(null), returnsNormally);
    });

    test('throws on map', () {
      expect(() => assertValidScalar({'a': 1}), throwsArgumentError);
    });

    test('throws on list', () {
      expect(() => assertValidScalar([1]), throwsArgumentError);
    });
  });

  group('compact char test', () {
    test(
      'Returns a valid index of the character used to declare block node'
      ' in compact-inline notation for an explicit key',
      () {
        const yaml = '''
? - block
  - sequence

? key: value
  another: value
''';

        final mapKeys = (loadYamlNode(
          yaml,
        ) as YamlMap)
            .nodes
            .keys
            .cast<YamlNode>()
            .toList();

        // Compact block lists
        expect(
          indexOfCompactChar(
            yaml,
            mapKeys.first.span.start.offset,
          ),
          equals((compactCharOffset: 0, lineEndingIndex: -1)),
        );

        // Compact block maps
        expect(
          indexOfCompactChar(
            yaml,
            mapKeys[1].span.start.offset,
          ),

          // Skip first "?"
          equals(
            (compactCharOffset: yaml.indexOf('?', 1), lineEndingIndex: -1),
          ),
        );
      },
    );

    test(
      'Returns a valid index of the character used to declare block node'
      ' in compact-inline notation for an explicit value',
      () {
        /// A key/value is always implicit unless an explicit key is seen.
        ///
        /// See paragraph after example 8.17 in Block Mappings section.
        const yaml = '''
? key
: - block
  - sequence

? another
: explict: block
  value: node
''';

        final values = (loadYamlNode(
          yaml,
        ) as YamlMap)
            .nodes
            .values
            .toList();

        final firstExplicitValueChar = yaml.indexOf(':');

        // Compact block lists
        expect(
          indexOfCompactChar(yaml, values.first.span.start.offset),
          equals(
            (compactCharOffset: firstExplicitValueChar, lineEndingIndex: -1),
          ),
        );

        // Compact block maps
        expect(
          indexOfCompactChar(yaml, values[1].span.start.offset),

          // Skip first ":"
          equals(
            (
              compactCharOffset: yaml.indexOf(':', firstExplicitValueChar + 1),
              lineEndingIndex: -1
            ),
          ),
        );
      },
    );

    test(
      'Returns a valid index of the character used to declare block node'
      ' in compact-inline notation for a block sequence',
      () {
        const yaml = '''
- - block
  - sequence

- key: value
  another: value
''';

        final elements = (loadYamlNode(
          yaml,
        ) as YamlList)
            .nodes;

        // Compact block lists
        expect(
          indexOfCompactChar(yaml, elements.first.span.start.offset),
          equals((compactCharOffset: 0, lineEndingIndex: -1)),
        );

        // Compact block maps
        expect(
          indexOfCompactChar(yaml, elements[1].span.start.offset),

          // Skip first "?"
          equals(
            (compactCharOffset: yaml.lastIndexOf('-'), lineEndingIndex: -1),
          ),
        );
      },
    );

    test('Returns index of line break when not compact', () {
      const yaml = '''
-
  - not compact
-
  ?
    - key not compact
  :
    - not compact
''';

      final list = (loadYamlNode(yaml) as YamlList).nodes;

      // First nested block sequence is not compact
      expect(
        indexOfCompactChar(yaml, list[0].span.start.offset),
        equals((compactCharOffset: -1, lineEndingIndex: yaml.indexOf('\n'))),
      );

      // Explicit key & value not compact.
      final map = list[1] as YamlMap;

      final entries = map.nodes;

      expect(
        indexOfCompactChar(
          yaml,
          entries.keys.cast<YamlNode>().first.span.start.offset,
        ),
        equals((
          compactCharOffset: -1,
          lineEndingIndex: yaml.indexOf('\n', map.span.start.offset)
        )),
      );

      expect(
        indexOfCompactChar(yaml, entries.values.first.span.start.offset),
        equals(
          (
            compactCharOffset: -1,
            lineEndingIndex: yaml.indexOf(
              '\n',
              yaml.indexOf(':', map.span.start.offset),
            )
          ),
        ),
      );
    });
  });

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

  group('getListIndentation', () {
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
