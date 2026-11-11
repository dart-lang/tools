// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('Element.textContent concatenates nested and unparsed text', () {
    final root = Element('p', [
      Text('a'),
      Element('strong', [
        Text('b'),
        Element('em', [Text('c')]),
      ]),
      UnparsedContent('d'),
    ]);
    expect(root.textContent, 'abcd');
    expect(Element.empty('hr').textContent, isEmpty);
  });

  test('deeply nested AST text extraction does not recurse', () {
    Node node = Text('שלום');
    for (var i = 0; i < 10000; i++) {
      node = Element('em', [node]);
    }
    expect(node.textContent, 'שלום');
  });

  test('Element.textContent respects subclass overrides', () {
    final parent = Element('p', [
      Text('before-'),
      _OverriddenElement(),
      Text('-after'),
    ]);
    expect(parent.textContent, 'before-custom-after');
  });
}

class _OverriddenElement extends Element {
  _OverriddenElement() : super('span', [Text('ignored')]);

  @override
  String get textContent => 'custom';
}
