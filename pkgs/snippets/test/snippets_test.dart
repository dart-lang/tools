// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checks/checks.dart';
import 'package:snippets/src/cli/cli.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('examples in this package are up to date', () async {
    final err = StringBuffer();
    await check(runSnippets(['validate'], out: StringBuffer(), err: err))
        .completes((it) => it.equals(0));
    check(err.toString()).isEmpty();
  });
}
