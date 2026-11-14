// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:test/test.dart';

void main() {
  test('ordinary BR is a line break but SVG BR is not', () {
    final svgBr = Document().createElementNS('http://www.w3.org/2000/svg', 'br')
      ..append(Text('inside'));
    final root = Element.tag('div')
      ..append(Text('before'))
      ..append(Element.tag('br'))
      ..append(Text('after'))
      ..append(svgBr)
      ..append(Text('end'));
    expect(
      root.textContent(convertBRsToNewlines: true),
      'before\nafterinsideend',
    );
  });

  test('5000-deep book text extraction does not recurse', () {
    final root = Element.tag('div');
    var child = root;
    for (var i = 0; i < 5000; i++) {
      final next = Element.tag('span');
      child.append(next);
      child = next;
    }
    child.append(Text('שלום עולם'));
    expect(root.text, 'שלום עולם');
    expect(root.textContent(convertBRsToNewlines: true), 'שלום עולם');
  });
}
