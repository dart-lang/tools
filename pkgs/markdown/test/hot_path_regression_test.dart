// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  test('task-list markers are parsed and stripped', () {
    final html = markdownToHtml(
      '- [x] checked\n'
      '- [X]\ttab\n'
      '-    [ ] indented\n'
      '- [ ]no space\n'
      '- [x]',
      extensionSet: ExtensionSet.gitHubFlavored,
    );
    expect(
      html,
      '<ul class="contains-task-list">\n'
      '<li class="task-list-item"><input type="checkbox" checked="true"></input>checked</li>\n'
      '<li class="task-list-item"><input type="checkbox" checked="true"></input>tab</li>\n'
      '<li class="task-list-item"><input type="checkbox"></input>indented</li>\n'
      '<li>[ ]no space</li>\n'
      '<li>[x]</li>\n'
      '</ul>\n',
    );
  });

  test('task-list markers are kept when the parser is disabled', () {
    expect(
      markdownToHtml('- [x] checked', extensionSet: ExtensionSet.commonMark),
      '<ul>\n<li>[x] checked</li>\n</ul>\n',
    );
  });

  test('link destinations preserve percent-encoded escapes', () {
    expect(normalizeLinkDestination('/a%20b?q=%26'), '/a%20b?q=%26');
    expect(normalizeLinkDestination('/hello-world'), '/hello-world');
  });

  test('heading anchors retain their normalization behavior', () {
    final element = Element.text('h2', '  Hello World!  ');
    expect(BlockSyntax.generateAnchorHash(element), 'hello-world');
  });
}
