// Copyright (c) project authors. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for details.

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  group('querySelector descendant', () {
    late Element el;

    setUp(() {
      el = Element.html('<div id="a" class="a"><div id="b"></div></div>');
    });

    test('descendant of type', () {
      expect(el.querySelector('div div')?.id, 'b');
    });

    test('descendant of class', () {
      expect(el.querySelector('.a div')?.id, 'b');
    });

    test('descendant of type and class', () {
      expect(el.querySelector('div.a div')?.id, 'b');
    });

    test('empty :not() throws FormatException', () {
      final isInvalidNotSelector = throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          "':not()' is not a valid selector",
        ),
      );
      expect(() => el.querySelector(':not()'), isInvalidNotSelector);
      expect(() => el.querySelectorAll(':not()'), isInvalidNotSelector);
    });
  });

  group('querySelectorAll', () {
    List<String> ids(Document doc, String selector) =>
        doc.querySelectorAll(selector).map((e) => e.id).toList();

    Document buildPseudoDoc() {
      final doc = parse(
        '<p id=empty></p>'
        '<p id=comment><!--c--></p>'
        '<p id=child-el><b></b><!--c--></p>'
        '<p id=text>x</p>'
        '<p id=space> </p>'
        '<p id=tab>\t</p>'
        '<p id=lf>\n</p>'
        '<p id=ff>\f</p>'
        '<p id=nbsp>\u00A0</p>'
        '<p id=em-space>\u2003</p>'
        '<p id=emoji>\u{1F600}</p>'
        '<p id=space-emoji> \u{1F600}</p>',
      );
      doc.body!
        ..append(Element.tag('p')
          ..id = 'cr'
          ..append(Text('\r')))
        ..append(Element.tag('p')
          ..id = 'empty-text'
          ..append(Text('')))
        ..append(Element.tag('p')
          ..id = 'empty-then-text'
          ..append(Text(''))
          ..append(Text('x')))
        ..append(Element.tag('p')
          ..id = 'lead-surrogate'
          ..append(Text('\uD800')))
        ..append(Element.tag('p')
          ..id = 'space-trail-surrogate'
          ..append(Text(' \uDC00')));
      return doc;
    }

    test(':empty matches elements with only comments or empty text', () {
      final doc = buildPseudoDoc();
      expect(ids(doc, 'p:empty'), ['empty', 'comment', 'empty-text']);
    });

    test(':blank also matches elements with only whitespace text', () {
      final doc = buildPseudoDoc();
      expect(
        ids(doc, 'p:blank'),
        ['empty', 'comment', 'space', 'tab', 'lf', 'ff', 'cr', 'empty-text'],
      );
    });
  });
}
