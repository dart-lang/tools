// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('fenced language and metadata may be separated by a tab', () {
    final html = markdownToHtml('```dart\tline-numbers\ncode\n```\n');
    expect(html, contains('class="language-dart"'));
    expect(html, contains('data-metadata="line-numbers"'));
  });

  test('tilde fence info is split at the first tab', () {
    final html = markdownToHtml('~~~ dart\t\tone two\ncode\n~~~\n');
    expect(html, contains('class="language-dart"'));
    expect(html, contains('data-metadata="\tone two"'));
  });

  test('space-delimited metadata preserves interior spacing', () {
    final html = markdownToHtml('```dart one  two\ncode\n```\n');
    expect(html, contains('class="language-dart"'));
    expect(html, contains('data-metadata="one  two"'));
  });
}
