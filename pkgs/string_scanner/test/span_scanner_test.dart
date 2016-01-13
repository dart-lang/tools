// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';

void main() {
  testForImplementation("lazy", () {
    return new SpanScanner('foo\nbar\nbaz', sourceUrl: 'source');
  });

  testForImplementation("eager", () {
    return new SpanScanner.eager('foo\nbar\nbaz', sourceUrl: 'source');
  });
}

void testForImplementation(String name, SpanScanner create()) {
  group("for a $name scanner", () {
    var scanner;
    setUp(() => scanner = create());

    test("tracks the span for the last match", () {
      scanner.scan('fo');
      scanner.scan('o\nba');

      var span = scanner.lastSpan;
      expect(span.start.offset, equals(2));
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(2));
      expect(span.start.sourceUrl, equals(Uri.parse('source')));

      expect(span.end.offset, equals(6));
      expect(span.end.line, equals(1));
      expect(span.end.column, equals(2));
      expect(span.start.sourceUrl, equals(Uri.parse('source')));

      expect(span.text, equals('o\nba'));
    });

    test(".spanFrom() returns a span from a previous state", () {
      scanner.scan('fo');
      var state = scanner.state;
      scanner.scan('o\nba');
      scanner.scan('r\nba');

      var span = scanner.spanFrom(state);
      expect(span.text, equals('o\nbar\nba'));
    });

    test(".emptySpan returns an empty span at the current location", () {
      scanner.scan('foo\nba');

      var span = scanner.emptySpan;
      expect(span.start.offset, equals(6));
      expect(span.start.line, equals(1));
      expect(span.start.column, equals(2));
      expect(span.start.sourceUrl, equals(Uri.parse('source')));

      expect(span.end.offset, equals(6));
      expect(span.end.line, equals(1));
      expect(span.end.column, equals(2));
      expect(span.start.sourceUrl, equals(Uri.parse('source')));

      expect(span.text, equals(''));
    });
  });
}
