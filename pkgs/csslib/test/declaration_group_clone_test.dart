// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

import 'testing.dart';

void main() {
  test('included mixin declarations keep groups and IE7 flags', () {
    final errors = <Message>[];
    final sheet = compileCss('''
@mixin m {
  *zoom: 1;
  width: (2 5);
}
div { @include m; }''', errors: errors, opts: simpleOptions);

    expect(errors, isEmpty);
    expect(prettyPrint(sheet), '''
div {
  *zoom: 1;
  width: (2 5);
}''');
  });
}
