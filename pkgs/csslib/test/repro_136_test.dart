// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';
import 'package:test/test.dart';

const options = PreprocessorOptions(
  useColors: false,
  warningsAsErrors: true,
  inputFile: 'memory',
);

void main() {
  test('repro_136', () {
    // Repro test for https://github.com/dart-lang/csslib/issues/136.
    final errors = <Message>[];

    final css = '''
.hero.is-white a:not(.button):not(.dropdown-item):not(.tag):not(.pagination-link.is-current),
.hero.is-white strong {
  color: inherit;
}
''';
    final stylesheet = parse(css, errors: errors, options: options);
    expect(stylesheet.topLevels, hasLength(1));
    var ruleset = stylesheet.topLevels.first as RuleSet;

    // This should be length 2.
    expect(ruleset.selectorGroup!.selectors, hasLength(1));

    // This test is expected to start to fail once we better support pseudo
    // selectors.
    // This should be empty.
    expect(errors, hasLength(3));
  });
}
