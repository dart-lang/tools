// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

import 'package:api_summary/src/node.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NodeTest);
  });
}

@reflectiveTest
class NodeTest {
  void test_printNodes_indentChildNodes() {
    final buf = StringBuffer();
    printNodes(buf, [
      (
        1,
        _simpleNode('one', [
          (2, _simpleNode('two')),
          (3, _simpleNode('three')),
        ]),
      ),
      (
        4,
        _simpleNode('four', [
          (5, _simpleNode('five')),
          (6, _simpleNode('six')),
        ]),
      ),
    ]);
    expect(buf.toString(), '''
one
  two
  three
four
  five
  six
''');
  }

  void test_printNodes_joinTextStrings() {
    final buf = StringBuffer();
    printNodes(buf, [
      (1, Node<num>()..text.addAll(['x', 0])),
    ]);
    expect(buf.toString(), '''
x0
''');
  }

  void test_printNodes_sortChildNodesByKey() {
    final buf = StringBuffer();
    printNodes(buf, [
      (
        0,
        _simpleNode('zero', [
          (2, _simpleNode('two')),
          (1, _simpleNode('one')),
          (3, _simpleNode('three')),
        ]),
      ),
    ]);
    expect(buf.toString(), '''
zero
  one
  two
  three
''');
  }

  void test_printNodes_sortedByKey() {
    final buf = StringBuffer();
    printNodes(buf, [
      (2, _simpleNode('two')),
      (1, _simpleNode('one')),
      (3, _simpleNode('three')),
    ]);
    expect(buf.toString(), '''
one
two
three
''');
  }
}

Node<num> _simpleNode(
  String text, [
  List<(num, Node<num>)> childNodes = const [],
]) {
  final node = Node<num>();
  node.text.add(text);
  node.childNodes.addAll(childNodes);
  return node;
}
