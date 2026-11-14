// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:csslib/parser.dart';
import 'package:test/test.dart';

void main() {
  test('indexed matching agrees with the linear matcher on full tables', () {
    for (var unit = TokenKind.UNIT_EM; unit < 700; unit++) {
      final name = TokenKind.unitToString(unit)!;
      if (name == '<BAD UNIT>') continue;
      expect(TokenKind.matchUnits(name, 0, name.length), unit, reason: name);
      final upper = 'x${name.toUpperCase()}';
      expect(TokenKind.matchUnits(upper, 1, name.length), unit, reason: name);
    }

    void checkTable(List<Map<String, Object>> table,
        int Function(String, int, int) indexed) {
      for (final entry in table) {
        final value = entry['value'] as String;
        for (final word in [
          value,
          value.toUpperCase(),
          '${value}x',
          value.substring(1),
        ]) {
          expect(indexed(word, 0, word.length),
              TokenKind.matchList(table, 'type', word, 0, word.length),
              reason: word);
        }
      }
    }

    checkTable(TokenKind.MARGIN_DIRECTIVES, TokenKind.matchMarginDirectives);
    checkTable(TokenKind.MEDIA_OPERATORS, TokenKind.matchMediaOperator);
  });
}
