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

    test(':empty matches elements with only comments or empty text', () {
      final doc = parse('<p id=a></p><p id=b><!--c--></p>'
          '<p id=c><b></b><!--c--></p><p id=d>x</p><p id=e> </p>');
      expect(ids(doc, 'p:empty'), ['a', 'b']);
    });

    test(':blank also matches elements with only whitespace text', () {
      final doc = parse('<p id=a></p><p id=b><!--c--></p>'
          '<p id=c><b></b><!--c--></p><p id=d>x</p><p id=e> </p>');
      expect(ids(doc, 'p:blank'), ['a', 'b', 'e']);
    });
  });
}
