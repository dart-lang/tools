// Copyright (c) 2019, the Dart project authors.
// Copyright (c) 2006, Kirill Simonov.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import 'package:source_span/source_span.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void _expectSpan(SourceSpan source, String expected) {
  final result = source.message('message');
  printOnFailure("r'''\n$result'''");

  expect(result, expected);
}

void main() {
  late YamlMap yaml;

  setUpAll(() {
    yaml = loadYaml(const JsonEncoder.withIndent(' ').convert({
      'num': 42,
      'nested': {
        'null': null,
        'num': 42,
      },
      'null': null,
    })) as YamlMap;
  });

  test('first root key', () {
    _expectSpan(
      yaml.nodes['num']!.span,
      r'''
line 2, column 9: message
  ╷
2 │  "num": 42,
  │         ^^
  ╵''',
    );
  });

  test('first root key', () {
    _expectSpan(
      yaml.nodes['null']!.span,
      r'''
line 7, column 10: message
  ╷
7 │  "null": null
  │          ^^^^
  ╵''',
    );
  });

  group('empty block node spans', () {
    test('mapping value starts after the value indicator', () {
      final yaml = loadYaml('key:\n') as YamlMap;
      final span = yaml.nodes['key']!.span;

      expect(span.start.offset, 4);
      expect(span.end.offset, 4);
    });

    test('sequence item starts after the entry indicator', () {
      final yaml = loadYaml('- \n') as YamlList;
      final span = yaml.nodes.first.span;

      expect(span.start.offset, 1);
      expect(span.end.offset, 1);
    });

    test('indentless sequence item starts after the entry indicator', () {
      final yaml = loadYaml('a:\n- \n- x\n') as YamlMap;
      final list = yaml.nodes['a'] as YamlList;
      final span = list.nodes.first.span;

      expect(span.start.offset, 4);
      expect(span.end.offset, 4);
    });

    test('explicit mapping value starts after the value indicator', () {
      final yaml = loadYaml('? a\n:\n') as YamlMap;
      final span = yaml.nodes['a']!.span;

      expect(span.start.offset, 5);
      expect(span.end.offset, 5);
    });

    test('sequence item with CRLF starts after the entry indicator', () {
      final yaml = loadYaml('- \r\n- x\r\n') as YamlList;
      final span = yaml.nodes.first.span;

      expect(span.start.offset, 1);
      expect(span.end.offset, 1);
    });
  });

  group('nested', () {
    late YamlMap nestedMap;

    setUpAll(() {
      nestedMap = yaml.nodes['nested'] as YamlMap;
    });

    test('first root key', () {
      _expectSpan(
        nestedMap.nodes['null']!.span,
        r'''
line 4, column 11: message
  ╷
4 │   "null": null,
  │           ^^^^
  ╵''',
      );
    });

    test('first root key', () {
      _expectSpan(
        nestedMap.nodes['num']!.span,
        r'''
line 5, column 10: message
  ╷
5 │     "num": 42
  │ ┌──────────^
6 │ │  },
  │ └─^
  ╵''',
      );
    });
  });

  group('block', () {
    late YamlList list, nestedList;

    setUpAll(() {
      const yamlStr = '''
- foo
- 
  - one
  - 
  - three
  - 
  - five
  -
- 
  a : b
  c : d
- bar
''';

      list = loadYaml(yamlStr) as YamlList;
      nestedList = list.nodes[1] as YamlList;
    });

    test('root nodes span', () {
      _expectSpan(list.nodes[0].span, r'''
line 1, column 3: message
  ╷
1 │ - foo
  │   ^^^
  ╵''');

      _expectSpan(list.nodes[1].span, r'''
line 3, column 3: message
  ╷
3 │ ┌   - one
4 │ │   - 
5 │ │   - three
6 │ │   - 
7 │ │   - five
8 │ └   -
  ╵''');

      _expectSpan(list.nodes[2].span, r'''
line 10, column 3: message
   ╷
10 │ ┌   a : b
11 │ └   c : d
   ╵''');

      _expectSpan(list.nodes[3].span, r'''
line 12, column 3: message
   ╷
12 │ - bar
   │   ^^^
   ╵''');
    });

    test('null nodes span', () {
      _expectSpan(nestedList.nodes[1].span, r'''
line 4, column 4: message
  ╷
4 │   - 
  │    ^
  ╵''');

      _expectSpan(nestedList.nodes[3].span, r'''
line 6, column 4: message
  ╷
6 │   - 
  │    ^
  ╵''');

      _expectSpan(nestedList.nodes[5].span, r'''
line 8, column 4: message
  ╷
8 │   -
  │    ^
  ╵''');
    });
  });
}
