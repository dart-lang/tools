// Copyright (c) 2026, the Dart project authors.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('retainLayout: false (default)', () {
    test('does not retain layout elements or spans by default', () {
      const yaml = '''
# Leading comment
key: value # Trailing comment
list:
  - item1
''';
      final doc = loadYamlDocument(yaml);
      final map = doc.contents as YamlMap;
      expect(map.leadingLayout, isEmpty);
      expect(map.trailingLayout, isEmpty);
      expect(map.colonSpan('key'), isNull);

      final keyNode = map.nodes.keys.first as YamlNode;
      expect(keyNode.leadingLayout, isEmpty);
      expect(keyNode.trailingLayout, isEmpty);

      final valNode = map.nodes['key']!;
      expect(valNode.leadingLayout, isEmpty);
      expect(valNode.trailingLayout, isEmpty);

      final list = map.nodes['list']! as YamlList;
      expect(list.dashSpan(0), isNull);
    });
  });

  group('retainLayout: true', () {
    test('captures leading and trailing comments on mapping entries', () {
      const yaml = '''
# Key comment
name: Bob # Same-line comment
# Another comment
age: 42
''';
      final doc = loadYamlDocument(yaml, retainLayout: true);
      final map = doc.contents as YamlMap;

      final nameKey = map.nodes.keys.first as YamlScalar;
      expect(
        nameKey.leadingLayout.whereType<CommentElement>().map((c) => c.text),
        contains('# Key comment'),
      );

      final nameVal = map.nodes['name']! as YamlScalar;
      expect(
        nameVal.trailingLayout.whereType<CommentElement>().map((c) => c.text),
        contains('# Same-line comment'),
      );
      final comment = nameVal.trailingLayout.whereType<CommentElement>().first;
      expect(comment.isTrailing, isTrue);

      final ageKey = map.nodes.keys.elementAt(1) as YamlScalar;
      expect(
        ageKey.leadingLayout.whereType<CommentElement>().map((c) => c.text),
        contains('# Another comment'),
      );
    });

    test('captures colon spans for block and flow mappings', () {
      const yaml = '''
block_key: block_value
flow: { a: 1, b: 2 }
''';
      final map = loadYaml(yaml, retainLayout: true) as YamlMap;

      final blockColon = map.colonSpan('block_key');
      expect(blockColon, isNotNull);
      expect(blockColon!.text, ':');

      // Lookup with YamlScalar key
      final keyScalar = map.nodes.keys.first;
      expect(map.colonSpan(keyScalar), blockColon);

      final flowMap = map.nodes['flow']! as YamlMap;
      final aColon = flowMap.colonSpan('a');
      expect(aColon, isNotNull);
      expect(aColon!.text, ':');

      final bColon = flowMap.colonSpan('b');
      expect(bColon, isNotNull);
      expect(bColon!.text, ':');
    });

    test('captures dash spans for block sequence entries', () {
      const yaml = '''
items:
  - first
  - second
  - third
''';
      final map = loadYaml(yaml, retainLayout: true) as YamlMap;
      final list = map.nodes['items']! as YamlList;

      expect(list.dashSpan(0), isNotNull);
      expect(list.dashSpan(0)!.text, '-');
      expect(list.dashSpan(1), isNotNull);
      expect(list.dashSpan(1)!.text, '-');
      expect(list.dashSpan(2), isNotNull);
      expect(list.dashSpan(2)!.text, '-');
      expect(list.dashSpan(3), isNull);
    });

    test('attaches comments preceding block sequence dashes to list items', () {
      const yaml = '''
list:
  # Item one
  - first
  # Item two
  - second
''';
      final map = loadYaml(yaml, retainLayout: true) as YamlMap;
      final list = map.nodes['list']! as YamlList;

      final item1 = list.nodes[0];
      expect(
        item1.leadingLayout.whereType<CommentElement>().map((c) => c.text),
        contains('# Item one'),
      );

      final item2 = list.nodes[1];
      expect(
        item2.leadingLayout.whereType<CommentElement>().map((c) => c.text),
        contains('# Item two'),
      );
    });

    test('captures whitespace and newline elements', () {
      const yaml = 'a: 1\n\nb: 2\n';
      final map = loadYaml(yaml, retainLayout: true) as YamlMap;

      final bKey = map.nodes.keys.elementAt(1) as YamlScalar;
      final newlines = bKey.leadingLayout.whereType<NewlineElement>();
      expect(newlines, isNotEmpty);
    });

    test('supports pattern matching on sealed LayoutElement hierarchy', () {
      const yaml = '# Comment\nkey: value\n';
      final map = loadYaml(yaml, retainLayout: true) as YamlMap;
      final key = map.nodes.keys.first as YamlScalar;

      for (final el in key.leadingLayout) {
        final description = switch (el) {
          CommentElement(:final text, :final isTrailing) =>
            'comment(trailing: $isTrailing): $text',
          WhitespaceElement(:final text) => 'whitespace(${text.length})',
          NewlineElement(:final text) => 'newline(${text.length})',
        };
        expect(description, isNotEmpty);
      }
    });

    test('wrappers preserve layout retention accessors', () {
      final map = YamlMap.wrap({'key': 'value'});
      expect(map.colonSpan('key'), isNull);
      expect(map.leadingLayout, isEmpty);
      expect(map.trailingLayout, isEmpty);

      final list = YamlList.wrap(['item']);
      expect(list.dashSpan(0), isNull);
      expect(list.leadingLayout, isEmpty);
      expect(list.trailingLayout, isEmpty);
    });
  });
}
