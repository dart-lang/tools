// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  group('structural selectors', () {
    test(':root matches the document element, not detached elements', () {
      final document = parse('<!doctype html><body><div id="child"></div>');
      expect(document.querySelector(':root'), same(document.documentElement));
      expect(document.body!.querySelector(':root'), isNull);
      expect(parseFragment('<div></div>').querySelector(':root'), isNull);
    });

    test(':nth-child counts element siblings starting with one', () {
      final document = parse(
        '<ul>text<!-- comment --><li id="first"></li>'
        '\n<li id="second"></li><li id="third"></li></ul>',
      );
      expect(document.querySelector('li:nth-child(1)')?.id, 'first');
      expect(document.querySelector('li:nth-child(2)')?.id, 'second');
      expect(document.querySelector('li:nth-child(3)')?.id, 'third');
      expect(document.querySelector('li:nth-child(4)'), isNull);
    });
  });

  test(':nth-child scans siblings at most quadratically across a query', () {
    const count = 100;
    final root = Element.tag('ul');
    final children = List.generate(count, (_) => _ComparisonCountingElement());
    root.nodes.addAll(children);
    _ComparisonCountingElement.comparisons = 0;

    expect(root.querySelectorAll(':nth-child($count)'), [same(children.last)]);
    expect(_ComparisonCountingElement.comparisons,
        lessThanOrEqualTo(count * count));
  });

  test('class tokens are separated by ASCII whitespace only', () {
    final element = Element.tag('span')..className = 'foo\tbar\nbaz\rqux\fquux';
    expect(element.classes.contains('bar'), isTrue);
    expect(element.classes.contains('qux'), isTrue);
    expect(element.classes.contains('foo bar'), isFalse);
    expect(element.classes, {'foo', 'bar', 'baz', 'qux', 'quux'});
    final parent = Element.tag('div')..append(element);
    expect(parent.querySelector('.baz'), same(element));
    expect(parent.querySelector('[class~=qux]'), same(element));
    expect(parent.querySelector('[class~="bar baz"]'), isNull);
    element.className = 'foo\u00a0bar';
    expect(element.classes.contains('foo'), isFalse);
    expect(element.classes.contains('foo\u00a0bar'), isTrue);
  });

  test('deep descendant queries retain preorder without recursion', () {
    final root = Element.tag('main');
    var current = root;
    for (var i = 0; i < 20000; i++) {
      final child = Element.tag('section');
      current.append(child);
      current = child;
    }
    current.append(Element.tag('span')..id = 'target');
    expect(root.querySelector('span')?.id, 'target');
    expect(root.querySelectorAll('span').single.id, 'target');
  });

  test('iterative querySelectorAll preserves preorder', () {
    final root = parseFragment(
      '<p><span id="one"></span></p>'
      '<span id="two"><span id="three"></span></span>',
    );
    expect(
      root.querySelectorAll('span').map((e) => e.id).toList(),
      ['one', 'two', 'three'],
    );
  });
}

class _ComparisonCountingElement extends Element {
  static int comparisons = 0;

  _ComparisonCountingElement() : super.tag('li');

  @override
  bool operator ==(Object other) {
    comparisons++;
    return identical(this, other);
  }

  @override
  int get hashCode => identityHashCode(this);
}
