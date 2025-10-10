// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  /// This is a test for spans of the generated file that continue over several
  /// lines.
  ///
  /// In a sourcemap, a span continues from the start encoded position until the
  /// next position, regardless of whether the second position in on the same
  /// line in the generated file or a subsequent line.
  void testSpans(int lineA, int columnA, int lineB, int columnB) {
    // Create a sourcemap describing a 'rectangular' generated file with three
    // spans, each potentially over several lines: (1) an initial span that is
    // unmapped, (2) a span that maps to file 'A', the span continuing until (3)
    // a span that maps to file 'B'.
    //
    // We can describe the mapping by an 'image' of the generated file, where
    // the positions marked as 'A' in the 'image' correspond to locations in the
    // generated file that map to locations in source file file 'A'. Lines and
    // columns are zero-based.
    //
    //       0123456789
    //    0: ----------
    //    1: ----AAAAAA         lineA: 1, columnA: 4, i.e. locationA
    //    2: AABBBBBBBB         lineB: 2, columnB: 2, i.e. locationB
    //    3: BBBBBBBBBB
    //
    // Once we have the mapping, we probe every position in a 8x10 rectangle to
    // validate that it maps to the intended original source file.

    expect(isBefore(lineB, columnB, lineA, columnA), isFalse,
        reason: 'Test valid only for ordered positions');

    SourceLocation location(Uri? uri, int line, int column) {
      final offset = line * 10 + column;
      return SourceLocation(offset, sourceUrl: uri, line: line, column: column);
    }

    // Locations in the generated file.
    final uriMap = Uri.parse('output.js.map');
    final locationA = location(uriMap, lineA, columnA);
    final locationB = location(uriMap, lineB, columnB);

    // Original source locations.
    final sourceA = location(Uri.parse('A'), 0, 0);
    final sourceB = location(Uri.parse('B'), 0, 0);

    final json = (SourceMapBuilder()
          ..addLocation(sourceA, locationA, null)
          ..addLocation(sourceB, locationB, null))
        .build(uriMap.toString());

    final mapping = parseJson(json);

    // Validate by comparing 'images' of the generate file.
    final expectedImage = StringBuffer();
    final actualImage = StringBuffer();

    for (var line = 0; line < 8; line++) {
      for (var column = 0; column < 10; column++) {
        final span = mapping.spanFor(line, column);
        final expected = isBefore(line, column, lineA, columnA)
            ? '-'
            : isBefore(line, column, lineB, columnB)
                ? 'A'
                : 'B';
        final actual = span?.start.sourceUrl?.path ?? '-'; // Unmapped -> '-'.

        expectedImage.write(expected);
        actualImage.write(actual);
      }
      expectedImage.writeln();
      actualImage.writeln();
    }
    expect(actualImage.toString(), expectedImage.toString());
  }

  test('continued span, same position', () {
    testSpans(2, 4, 2, 4);
  });

  test('continued span, same line', () {
    testSpans(2, 4, 2, 7);
  });

  test('continued span, next line, earlier column', () {
    testSpans(2, 4, 3, 2);
  });

  test('continued span, next line, later column', () {
    testSpans(2, 4, 3, 6);
  });

  test('continued span, later line, earlier column', () {
    testSpans(2, 4, 5, 2);
  });

  test('continued span, later line, later column', () {
    testSpans(2, 4, 5, 6);
  });
}

bool isBefore(int line1, int column1, int line2, int column2) {
  return line1 < line2 || line1 == line2 && column1 < column2;
}
