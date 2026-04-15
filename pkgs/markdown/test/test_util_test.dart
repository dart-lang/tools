// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';
import 'util.dart';

void main() {
  group('NodeMatcher', () {
    // Simple element.
    final foo = Element('foo', []);
    // No nested elements.
    final fooTextAttr = Element('foo', [Text('text')], {'key': 'value'});
    // Element which is self-closing.
    final fooEmpty = Element.empty('foo', {'key': 'value'});
    // Nested elements.
    final nested = Element(
      'outer',
      [
        Text('<mid'),
        Element(
          'middle',
          [
            Text('<inner'),
            Element.empty('inner', {'innerKey': 'innerValue'}),
            Text('inner>'),
          ],
          {'midKey': 'midValue'},
        ),
        Text('mid>'),
      ],
      {'outerKey': 'outerValue'},
    );

    group('TextMatcher', () {
      test('literal match', () {
        expect(Text('text'), isText('text'));
        expect(Text('text'), isText(Text('text')));
        expect(Text('text'), TextMatcher('text'));
        expect(Text('text'), TextMatcher(Text('text')));
        expect(Text('text'), TextMatcher.of(Text('text')));
      });
      test('string matcher match', () {
        expect(Text('text'), isText(startsWith('tex')));
        expect(Text('text'), TextMatcher(startsWith('tex')));
      });

      test('fails when not same text', () {
        expect(Text('text'), isNot(isText('other')));
        expect(Text('text'), isNot(Text('other')));
        expect(Text('text'), isNot(TextMatcher('other')));
        expect(Text('text'), isNot(TextMatcher(Text('other'))));
      });

      test('fails when string matcher does not match', () {
        expect(Text('text'), isNot(isText(startsWith('not'))));
        expect(Text('text'), isNot(TextMatcher(startsWith('not'))));
      });
    });

    group('ElementMatcher', () {
      // Simple element.
      testMatcher('can pass element to `isElement`', foo, foo);
      testMatcher('can pass string tag', foo, 'foo');
      testMatcher('can pass empty list of children', foo, 'foo', children: []);
      testMatcher(
        'can pass empty map of attributes',
        foo,
        'foo',
        attributes: {},
      );
      testMatcher(
        'can pass null as children and empty map as attributes',
        foo,
        'foo',
        children: [],
        attributes: {},
      );
      testMatcher(
        fails: true,
        'empty children is not no children',
        foo,
        'foo',
        children: [],
        attributes: {},
        isEmpty: true,
      );

      // Does not check children or attributes if `null`.
      testMatcher(
        'does not check children or attributes if not provided',
        fooTextAttr,
        'foo',
      );

      testMatcher(
        'can match Text children by strings',
        fooTextAttr,
        'foo',
        children: ['text'],
      );
      testMatcher(
        'can match Text children by Text objects',
        fooTextAttr,
        'foo',
        children: [Text('text')],
      );
      testMatcher(
        'can match Text children by TextMatchers',
        fooTextAttr,
        'foo',
        children: [isText('text')],
      );

      testMatcher(
        'can match attributes without children',
        fooTextAttr,
        'foo',
        attributes: {'key': 'value'},
      );
      testMatcher(
        'can match attributes and children',
        fooTextAttr,
        'foo',
        children: [isText('text')],
        attributes: {'key': 'value'},
      );

      testMatcher(
        fails: true,
        'Non-null children must match',
        fooTextAttr,
        'foo',
        children: [],
      );

      testMatcher(
        fails: true,
        'Text must match text content',
        fooTextAttr,
        'foo',
        children: ['other text'],
      );

      testMatcher(
        fails: true,
        'No extra children',
        fooTextAttr,
        'foo',
        children: ['text', 'more text'],
      );

      testMatcher(
        fails: true,
        'Non-null attributes must match every entry',
        fooTextAttr,
        'foo',
        attributes: {},
      );

      testMatcher(
        fails: true,
        'Non-null attributes must match every entry value',
        fooTextAttr,
        'foo',
        attributes: {'key': 'not value'},
      );

      testMatcher(
        fails: true,
        'Non-null attributes must not match other entires',

        fooTextAttr,
        'foo',
        attributes: {'key': 'value', 'otherKey': 'otherValue'},
      );

      testMatcher(
        'can use matchers for tag, children, and attribute values',

        fooTextAttr,
        startsWith('fo'),
        children: [isText(startsWith('tex'))],
        attributes: {'key': startsWith('val')},
      );

      testMatcher(
        'can use matchers for entire children and attribute maps',
        fooTextAttr,
        startsWith('fo'),
        children: isNot(isEmpty),
        attributes: isNot(isEmpty),
      );

      testMatcher(
        'empty element',
        fooEmpty,
        'foo',
        attributes: {'key': 'value'},
        isEmpty: true,
      );

      testMatcher(
        'empty element has null children',
        fooEmpty,
        'foo',
        children: isNull,
        attributes: {'key': 'value'},
      );

      testMatcher(
        fails: true,
        'empty element has no children',
        fooEmpty,
        'foo',
        children: [],
        attributes: {'key': 'value'},
      );

      testMatcher(
        fails: true,
        'empty element is empty',
        fooEmpty,
        'foo',
        attributes: {'key': 'value'},
        isEmpty: false,
      );

      // Matches self.
      testMatcher('nested elements', nested, nested);

      // Matches the same structure created as a matcher.
      testMatcher(
        'nested elements',
        nested,
        'outer',
        children: [
          isText('<mid'),
          isElement(
            'middle',
            [
              isText('<inner'),
              isEmptyElement('inner', {'innerKey': 'innerValue'}),
              isText('inner>'),
            ],
            {'midKey': 'midValue'},
          ),
          isText('mid>'),
        ],
        attributes: {'outerKey': 'outerValue'},
      );
    });

    test('NodeMatcher.of', () {
      expect(foo, NodeMatcher.of(foo));
      expect(fooTextAttr, NodeMatcher.of(fooTextAttr));
      expect(nested, NodeMatcher.of(nested));
      expect(Text('text'), NodeMatcher.of(Text('text')));
    });
  });
}

/// Helper function used by [ElementMatcher] testing.
///
/// Tests that the same parmeters to `isElement` and `ElementMatcher` works.
void testMatcher(
  String name,
  Object item,
  Object tag, {
  Object? children,
  Object? attributes,
  bool? isEmpty,
  bool fails = false,
}) {
  group(name, () {
    test('using isElement', () {
      Matcher matcher = isElement(tag, children, attributes, isEmpty);
      expect(item, fails ? isNot(matcher) : matcher);
    });
    test('using ElementMatcher', () {
      Matcher matcher = ElementMatcher(
        tag,
        children: children,
        attributes: attributes,
        isEmpty: isEmpty,
      );
      expect(item, fails ? isNot(matcher) : matcher);
    });
  });
}
