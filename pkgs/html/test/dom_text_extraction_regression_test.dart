// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  test('text and textContent agree for mixed Hebrew markup', () {
    final fragment = parseFragment(
      '<section>אב<span>גד<b>הו</b></span>'
      '<!-- ignored --><br><svg><text>זח</text></svg>'
      '<p>ט</p></section>',
    );
    final section = fragment.children.single;
    expect(section.text, 'אבגדהוזחט');
    expect(section.textContent(convertBRsToNewlines: false), 'אבגדהוזחט');
    expect(section.textContent(convertBRsToNewlines: true), 'אבגדהו\nזחט');
    expect(fragment.text, 'אבגדהוזחט');
  });

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

  test('BR element itself converts to a newline', () {
    final br = Element.tag('br');
    expect(br.text, '');
    expect(br.textContent(convertBRsToNewlines: true), '\n');
    final svgBr =
        Document().createElementNS('http://www.w3.org/2000/svg', 'br');
    expect(svgBr.textContent(convertBRsToNewlines: true), '');
  });

  test('comments and doctype are not included in concatenated text', () {
    final fragment = DocumentFragment()
      ..append(Comment('skip'))
      ..append(Text('א'))
      ..append(Element.tag('span')..append(Text('ב')));
    expect(fragment.text, 'אב');
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

  test('empty elements and fragments produce empty text', () {
    expect(Element.tag('div').text, '');
    expect(DocumentFragment().text, '');
  });
}
