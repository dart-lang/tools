// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  group('direct DOM lookups', () {
    test('IDs with punctuation, whitespace and digits match exactly', () {
      final document = parse('<div id="a:b"></div>'
          '<div id="a b"></div><p id="123"></p>');
      expect(document.getElementById('a:b')?.localName, 'div');
      expect(document.getElementById('a b')?.localName, 'div');
      expect(document.getElementById('123')?.localName, 'p');
      expect(document.getElementById(''), isNull);
      expect(document.getElementById('A:B'), isNull);
      expect(document.getElementById('missing'), isNull);
    });

    test('lookups visit descendants in document order, not the root', () {
      final root = Element.html('<div id="parent">'
          '<span id="one" class="first common"></span>'
          'text<span id="two" class="second common"></span></div>');
      expect(root.getElementsByTagName('div'), isEmpty);
      expect(
          root.getElementsByTagName('SPAN').map((e) => e.id), ['one', 'two']);
      expect(root.getElementsByTagName('*').map((e) => e.id), ['one', 'two']);
      expect(root.getElementsByClassName('common').map((e) => e.id),
          ['one', 'two']);
      expect(root.getElementsByClassName('common first').map((e) => e.id),
          ['one']);
      expect(root.getElementsByClassName('first common').map((e) => e.id),
          ['one']);
      expect(root.getElementsByClassName('common absent'), isEmpty);
    });

    test('class names handle all HTML whitespace and empty query', () {
      final document = parse(
        '<div id="one" class="alpha&#9;beta&#10;gamma"></div>'
        '<div id="two" class="alpha beta"></div>',
      );
      expect(document.getElementsByClassName('alpha\tbeta').map((e) => e.id),
          ['one', 'two']);
      expect(document.getElementsByClassName('gamma\nalpha').map((e) => e.id),
          ['one']);
      expect(document.getElementsByClassName(' \n\t '), isEmpty);
      expect(document.getElementsByClassName(''), isEmpty);
    });

    test('fragment can find IDs regardless of CSS identifier syntax', () {
      final fragment = parseFragment(
        '<section id="ab:cd"><b id="lead"></b></section>',
      );
      expect(fragment.getElementById('ab:cd'), same(fragment.children.first));
      expect(fragment.getElementById('lead')?.localName, 'b');
    });

    test('deep ID, class and tag lookups do not recurse', () {
      final fragment = DocumentFragment();
      final root = Element.tag('div');
      fragment.append(root);
      var current = root;
      for (var i = 0; i < 100000; i++) {
        final child = Element.tag('div');
        current.append(child);
        current = child;
      }
      current.append(Element.tag('span')
        ..id = 'found:123'
        ..className = 'book heading');
      expect(fragment.getElementById('found:123')?.localName, 'span');
      expect(root.getElementsByTagName('span'), hasLength(1));
      expect(root.getElementsByClassName('book heading'), hasLength(1));
    });
  });
}
