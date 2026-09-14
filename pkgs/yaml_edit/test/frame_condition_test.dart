// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('frame condition assertions', () {
    test('succeeds when comments outside the edit are preserved', () {
      final yaml = '''
# Header comment
foo: 123 # Inline comment
bar: 456 # Bar comment
# Footer comment
''';
      final editor = YamlEditor(yaml);
      editor.update(['foo'], 999);
      expect(editor.toString(), contains('# Header comment'));
      expect(editor.toString(), contains('# Bar comment'));
      expect(editor.toString(), contains('# Footer comment'));
    });

    test('allows removing comments belonging to the removed map entry', () {
      final yaml = '''
# Header
foo:
  nested: 1 # Foo nested comment
bar: 2 # Bar comment
''';
      final editor = YamlEditor(yaml);
      editor.remove(['foo']);
      expect(editor.toString(), contains('# Header'));
      expect(editor.toString(), contains('# Bar comment'));
      expect(editor.toString(), isNot(contains('# Foo nested comment')));
    });

    test('allows removing comments belonging to the removed list item', () {
      final yaml = '''
# Header
- a # Comment a
- b # Comment b
''';
      final editor = YamlEditor(yaml);
      editor.remove([0]);
      expect(editor.toString(), contains('# Header'));
      expect(editor.toString(), contains('# Comment b'));
      expect(editor.toString(), isNot(contains('# Comment a')));
    });

    test('detects unintentional removal of comments on same-line colon', () {
      final yaml = '''
key: # Comment on key line
  value
''';
      final editor = YamlEditor(yaml);
      expect(
        () => editor.update(['key'], 'new_value'),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Frame condition violation'),
          ),
        ),
      );
    });

    test('detects unintentional removal of comments in flow sequence removal',
        () {
      final yaml = '''
[word1
# comment
, word2]
''';
      final editor = YamlEditor(yaml);
      expect(
        () => editor.remove([0]),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Frame condition violation'),
          ),
        ),
      );
    });

    test('succeeds when replacing entire document', () {
      final yaml = '''
# Header
foo: 123
''';
      final editor = YamlEditor(yaml);
      editor.update([], {'bar': 456});
      expect(editor.toString(), contains('bar: 456'));
    });
  });
}
