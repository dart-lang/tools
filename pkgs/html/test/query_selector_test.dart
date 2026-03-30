// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:html/dom.dart';
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
  });
}
