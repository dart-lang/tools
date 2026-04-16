// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';
import 'util.dart';

void main() {
  group('linkResolver', () {
    List<Node> parseWithResolver(
      Resolver Function(Document) linkResolver,
      String source,
    ) {
      Document? document;
      Resolver? resolver;
      document = Document(
        linkResolver: (String label, [String? title]) =>
            // Give the link resolver access to the document.
            (resolver ??= linkResolver(document!))(label, title),
      );
      return document.parseLineList(source.toLines());
    }

    test('linkResolver called with both parts of [title][label]', () {
      var called = 0;
      final nodes = parseWithResolver(
        (_) => (String label, [String? title]) {
          expect(label, 'bananas');
          expect(title, 'yellow things');
          called++;
          final link = Element('a', [Text(title!)]);
          link.attributes['href'] = 'http://example.com/$label.html';
          return link;
        },
        'This is [yellow things][bananas]!',
      );
      expect(called, 1);
      expect(nodes, [
        isElement('p', [
          // ignore: prefer_single_quotes
          "This is ",
          isElement(
            'a',
            ['yellow things'],
            {'href': 'http://example.com/bananas.html'},
          ),
          '!',
        ]),
      ]);
    });

    test('sanity', () {
      expect({'href': '/'}, equals({'href': '/'}));
      expect(equals({'href': '/'}).matches({'href': '/'}, {}), true);
      expect(
        Element('a', [
          Element('em', [Text('text')], {'href': '/'}),
        ]),
        isElement(
          'a',
          [
            isElement('em', [isText('text')]),
          ],
          //{'href': '/'},
        ),
      );
    });

    test('linkResolver called with `null` title if none given', () {
      var called = 0;
      final nodes = parseWithResolver(
        (Document document) => (String label, [String? title]) {
          called++;
          final content = (title != null)
              ? document.parseInline(title)
              : [Text(label)];
          final link = Element('a', content)
            ..attributes['href'] = '/$label.html';
          return link;
        },
        '''
* A raw [RefLink1].
* An implicit label [RefLink2][].
* An explicit label [_RefLabel3_][RefLink3].
        ''',
      );
      expect(called, 3);
      expect(nodes, [
        isElement('ul', [
          isElement('li', [
            'A raw ',
            isElement('a', ['RefLink1'], {'href': '/RefLink1.html'}),
            '.',
          ]),
          isElement('li', [
            'An implicit label ',
            isElement('a', ['RefLink2'], {'href': '/RefLink2.html'}),
            '.',
          ]),
          isElement('li', [
            'An explicit label ',
            isElement(
              'a',
              [
                isElement('em', ['RefLabel3']),
              ],
              {'href': '/RefLink3.html'},
            ),
            '.',
          ]),
        ]),
      ]);
    });
  });
}
