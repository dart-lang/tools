// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  group('parent pointer invariants', () {
    test('nodes.remove detaches the removed node', () {
      final parent = Element.tag('div');
      final child = Element.tag('span');
      parent.append(child);
      expect(parent.nodes.remove(child), isTrue);
      expect(child.parentNode, isNull);
      expect(parent.nodes, isEmpty);
      expect(parent.nodes.remove(child), isFalse);
    });

    test('replacing with an earlier sibling adjusts the index', () {
      final parent = Element.tag('div');
      final a = Element.tag('a');
      final b = Element.tag('b');
      final c = Element.tag('c');
      parent.nodes.addAll([a, b, c]);
      parent.nodes[2] = a;
      expect(parent.nodes, [b, a]);
      expect(c.parentNode, isNull);
      expect(a.parentNode, same(parent));
      expect(b.parentNode, same(parent));
      parent.nodes[1] = a;
      expect(parent.nodes, [b, a]);
    });

    test('replacing with a later sibling preserves other children', () {
      final parent = Element.tag('div');
      final a = Element.tag('a');
      final b = Element.tag('b');
      final c = Element.tag('c');
      parent.nodes.addAll([a, b, c]);
      parent.nodes[0] = c;
      expect(parent.nodes, [c, b]);
      expect(a.parentNode, isNull);
      expect(c.parentNode, same(parent));
    });

    test('insert moves an earlier sibling to the end', () {
      final parent = Element.tag('div');
      final a = Element.tag('a');
      final b = Element.tag('b');
      final c = Element.tag('c');
      parent.nodes.addAll([a, b, c]);
      parent.nodes.insert(3, a);
      expect(parent.nodes, [b, c, a]);
      for (final child in parent.nodes) {
        expect(child.parentNode, same(parent));
      }
    });

    test('insertBefore moves an earlier sibling before the reference', () {
      final parent = Element.tag('div');
      final a = Element.tag('a');
      final b = Element.tag('b');
      final c = Element.tag('c');
      parent.nodes.addAll([a, b, c]);
      parent.insertBefore(a, c);
      expect(parent.nodes, [b, a, c]);
      a.remove();
      expect(a.parentNode, isNull);
      expect(parent.nodes, [b, c]);
    });

    test('insertAll moves siblings without duplicates', () {
      final parent = Element.tag('div');
      final a = Element.tag('a');
      final b = Element.tag('b');
      final c = Element.tag('c');
      final d = Element.tag('d');
      parent.nodes.addAll([a, b, c, d]);
      parent.nodes.insertAll(3, [a, b]);
      expect(parent.nodes, [c, a, b, d]);
      for (final child in parent.nodes) {
        expect(child.parentNode, same(parent));
      }
    });
  });

  group('bulk fragment insertion', () {
    test('reparentChildren keeps order and empties the source', () {
      final from = parseFragment('<p>א</p><hr><p>ב</p>');
      final to = Element.tag('article');
      from.reparentChildren(to);
      expect(from.nodes, isEmpty);
      expect(to.children.map((e) => e.localName), ['p', 'hr', 'p']);
      for (final node in to.nodes) {
        expect(node.parentNode, same(to));
      }
      to.reparentChildren(to);
      expect(to.children, hasLength(3));
    });

    test('inserting a large fragment moves all nodes once', () {
      final source = DocumentFragment();
      for (var i = 0; i < 1000; i++) {
        source.append(Element.tag('span')..id = '$i');
      }
      final destination = Element.tag('div');
      destination.nodes.addAll(source.nodes);
      expect(source.nodes, isEmpty);
      expect(destination.children.length, 1000);
      expect(destination.children.first.id, '0');
      expect(destination.children.last.id, '999');
    });

    test('innerHtml replaces children without stale parent pointers', () {
      final target = Element.tag('div');
      final old = Element.tag('b');
      target.append(old);
      target.innerHtml = '<i>חדש</i><span>טקסט</span>';
      expect(old.parentNode, isNull);
      expect(target.children.map((e) => e.localName), ['i', 'span']);
      expect(target.text, 'חדש' 'טקסט');
    });
  });

  test('children.forEach is safe when callbacks remove children', () {
    final parent = Element.tag('div');
    final one = Element.tag('b');
    final two = Element.tag('i');
    parent.nodes.addAll([one, Text('text'), two]);
    final visited = <Element>[];
    void visitAndRemove(Element child) {
      visited.add(child);
      child.remove();
    }

    parent.children.forEach(visitAndRemove);
    expect(visited, [one, two]);
    expect(parent.children, isEmpty);
    expect(one.parentNode, isNull);
    expect(two.parentNode, isNull);
  });

  test('live children traversal ignores non-elements and preserves order', () {
    final parent = Element.tag('div')
      ..append(Text('before'))
      ..append(Element.tag('b'))
      ..append(Comment('comment'))
      ..append(Element.tag('i'))
      ..append(Text('after'));
    expect(parent.children.length, 2);
    expect(parent.children.first.localName, 'b');
    expect(parent.children.last.localName, 'i');
    expect(parent.children.map((e) => e.localName), ['b', 'i']);
    expect(parent.children.reversed.map((e) => e.localName), ['i', 'b']);
    expect(parent.children[0].localName, 'b');
    expect(parent.children[1].localName, 'i');
    expect(parent.children.join(','), '<html b>,<html i>');
  });
}
