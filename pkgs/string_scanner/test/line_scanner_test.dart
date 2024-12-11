// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:string_scanner/src/charcode.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';

void main() {
  late LineScanner scanner;
  setUp(() {
    scanner = LineScanner('foo\nbar\r\nbaz');
  });

  test('begins with line and column 0', () {
    expect(scanner.line, equals(0));
    expect(scanner.column, equals(0));
  });

  group('scan()', () {
    test('consuming no newlines increases the column but not the line', () {
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));
    });

    test('consuming a LF resets the column and increases the line', () {
      scanner.expect('foo\nba');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(2));
    });

    test('consuming multiple LFs resets the column and increases the line', () {
      scanner.expect('foo\nbar\r\nb');
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('consuming a CR LF increases the line only after the LF', () {
      scanner.expect('foo\nbar\r');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));

      scanner.expect('\nb');
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('consuming a CR not followed by LF increases the line', () {
      scanner = LineScanner('foo\nbar\rbaz');
      scanner.expect('foo\nbar\r');
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));

      scanner.expect('b');
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('consuming a CR at the end increases the line', () {
      scanner = LineScanner('foo\nbar\r');
      scanner.expect('foo\nbar\r');
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
      expect(scanner.isDone, isTrue);
    });

    test('consuming a mix of CR, LF, CR+LF increases the line', () {
      scanner = LineScanner('0\n1\r2\r\n3');
      scanner.expect('0\n1\r2\r\n3');
      expect(scanner.line, equals(3));
      expect(scanner.column, equals(1));
    });

    test('scanning a zero length match between CR LF does not fail', () {
      scanner.expect('foo\nbar\r');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));
      scanner.expect(RegExp('(?!x)'));
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));
    });
  });

  group('readChar()', () {
    test('on a non-newline character increases the column but not the line',
        () {
      scanner.readChar();
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(1));
    });

    test('consuming a LF resets the column and increases the line', () {
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.readChar();
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR LF increases the line only after the LF', () {
      scanner = LineScanner('foo\r\nbar');
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.readChar();
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(4));

      scanner.readChar();
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR not followed by a LF increases the line', () {
      scanner = LineScanner('foo\nbar\rbaz');
      scanner.expect('foo\nbar');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(3));

      scanner.readChar();
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR at the end increases the line', () {
      scanner = LineScanner('foo\nbar\r');
      scanner.expect('foo\nbar');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(3));

      scanner.readChar();
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });

    test('consuming a mix of CR, LF, CR+LF increases the line', () {
      scanner = LineScanner('0\n1\r2\r\n3');
      for (var i = 0; i < scanner.string.length; i++) {
        scanner.readChar();
      }

      expect(scanner.line, equals(3));
      expect(scanner.column, equals(1));
    });
  });

  group('readCodePoint()', () {
    test('on a non-newline character increases the column but not the line',
        () {
      scanner.readCodePoint();
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(1));
    });

    test('consuming a newline resets the column and increases the line', () {
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.readCodePoint();
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test("consuming halfway through a CR LF doesn't count as a line", () {
      scanner.expect('foo\nbar');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(3));

      scanner.readCodePoint();
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));

      scanner.readCodePoint();
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });
  });

  group('scanChar()', () {
    test('on a non-newline character increases the column but not the line',
        () {
      scanner.scanChar($f);
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(1));
    });

    test('consuming a LF resets the column and increases the line', () {
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.scanChar($lf);
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR LF increases the line only after the LF', () {
      scanner.expect('foo\nbar');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(3));

      scanner.scanChar($cr);
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));

      scanner.scanChar($lf);
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR not followed by LF increases the line', () {
      scanner = LineScanner('foo\rbar');
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.scanChar($cr);
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test('consuming a CR at the end increases the line', () {
      scanner = LineScanner('foo\r');
      scanner.expect('foo');
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(3));

      scanner.scanChar($cr);
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(0));
    });

    test('consuming a mix of CR, LF, CR+LF increases the line', () {
      scanner = LineScanner('0\n1\r2\r\n3');
      for (var i = 0; i < scanner.string.length; i++) {
        scanner.scanChar(scanner.string[i].codeUnits.single);
      }

      expect(scanner.line, equals(3));
      expect(scanner.column, equals(1));
    });
  });

  group('before a surrogate pair', () {
    final codePoint = '\uD83D\uDC6D'.runes.first;
    const highSurrogate = 0xD83D;

    late LineScanner scanner;
    setUp(() {
      scanner = LineScanner('foo: \uD83D\uDC6D');
      expect(scanner.scan('foo: '), isTrue);
    });

    test('readChar returns the high surrogate and moves into the pair', () {
      expect(scanner.readChar(), equals(highSurrogate));
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(6));
      expect(scanner.position, equals(6));
    });

    test('readCodePoint returns the code unit and moves past the pair', () {
      expect(scanner.readCodePoint(), equals(codePoint));
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(7));
      expect(scanner.position, equals(7));
    });

    test('scanChar with the high surrogate moves into the pair', () {
      expect(scanner.scanChar(highSurrogate), isTrue);
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(6));
      expect(scanner.position, equals(6));
    });

    test('scanChar with the code point moves past the pair', () {
      expect(scanner.scanChar(codePoint), isTrue);
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(7));
      expect(scanner.position, equals(7));
    });

    test('expectChar with the high surrogate moves into the pair', () {
      scanner.expectChar(highSurrogate);
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(6));
      expect(scanner.position, equals(6));
    });

    test('expectChar with the code point moves past the pair', () {
      scanner.expectChar(codePoint);
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(7));
      expect(scanner.position, equals(7));
    });
  });

  group('position=', () {
    test('forward through LFs sets the line and column', () {
      scanner = LineScanner('foo\nbar\nbaz');
      scanner.position = 9; // "foo\nbar\nb"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('forward from non-zero character through LFs sets the line and column',
        () {
      scanner = LineScanner('foo\nbar\nbaz');
      scanner.expect('fo');
      scanner.position = 9; // "foo\nbar\nb"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('forward through CR LFs sets the line and column', () {
      scanner = LineScanner('foo\r\nbar\r\nbaz');
      scanner.position = 11; // "foo\r\nbar\r\nb"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('forward through CR not followed by LFs sets the line and column', () {
      scanner = LineScanner('foo\rbar\rbaz');
      scanner.position = 9; // "foo\rbar\rb"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test('forward through CR at end sets the line and column', () {
      scanner = LineScanner('foo\rbar\r');
      scanner.position = 8; // "foo\rbar\r"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });

    test('forward through a mix of CR, LF, CR+LF sets the line and column', () {
      scanner = LineScanner('0\n1\r2\r\n3');
      scanner.position = scanner.string.length;

      expect(scanner.line, equals(3));
      expect(scanner.column, equals(1));
    });

    test('forward through no newlines sets the column', () {
      scanner.position = 2; // "fo"
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(2));
    });

    test('backward through LFs sets the line and column', () {
      scanner = LineScanner('foo\nbar\nbaz');
      scanner.expect('foo\nbar\nbaz');
      scanner.position = 2; // "fo"
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(2));
    });

    test('backward through CR LFs sets the line and column', () {
      scanner = LineScanner('foo\r\nbar\r\nbaz');
      scanner.expect('foo\r\nbar\r\nbaz');
      scanner.position = 2; // "fo"
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(2));
    });

    test('backward through CR not followed by LFs sets the line and column',
        () {
      scanner = LineScanner('foo\rbar\rbaz');
      scanner.expect('foo\rbar\rbaz');
      scanner.position = 2; // "fo"
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(2));
    });

    test('backward through CR at end sets the line and column', () {
      scanner = LineScanner('foo\rbar\r');
      scanner.expect('foo\rbar\r');
      scanner.position = 2; // "fo"
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(2));
    });

    test('backward through a mix of CR, LF, CR+LF sets the line and column',
        () {
      scanner = LineScanner('0\n1\r2\r\n3');
      scanner.expect(scanner.string);

      scanner.position = 1;
      expect(scanner.line, equals(0));
      expect(scanner.column, equals(1));
    });

    test('backward through no newlines sets the column', () {
      scanner.expect('foo\nbar\r\nbaz');
      scanner.position = 10; // "foo\nbar\r\nb"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(1));
    });

    test("forward halfway through a CR LF doesn't count as a line", () {
      scanner.position = 8; // "foo\nbar\r"
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));
    });

    test('forward from halfway through a CR LF counts as a line', () {
      scanner.expect('foo\nbar\r');
      scanner.position = 11; // "foo\nbar\r\nba"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(2));
    });

    test('backward to between CR LF', () {
      scanner.expect('foo\nbar\r\nbaz');
      scanner.position = 8; // "foo\nbar\r"
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));
    });

    test('backward from between CR LF', () {
      scanner.expect('foo\nbar\r');
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(4));
      scanner.position = 5; // "foo\nb"
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(1));
    });

    test('backward to after CR LF', () {
      scanner.expect('foo\nbar\r\nbaz');
      scanner.position = 9; // "foo\nbar\r\n"
      expect(scanner.line, equals(2));
      expect(scanner.column, equals(0));
    });

    test('backward to before CR LF', () {
      scanner.expect('foo\nbar\r\nbaz');
      scanner.position = 7; // "foo\nbar"
      expect(scanner.line, equals(1));
      expect(scanner.column, equals(3));
    });
  });

  test('state= restores the line, column, and position', () {
    scanner.expect('foo\nb');
    final state = scanner.state;

    scanner.scan('ar\nba');
    scanner.state = state;
    expect(scanner.rest, equals('ar\r\nbaz'));
    expect(scanner.line, equals(1));
    expect(scanner.column, equals(1));
  });

  test('state= rejects a foreign state', () {
    scanner.scan('foo\nb');

    expect(() => LineScanner(scanner.string).state = scanner.state,
        throwsArgumentError);
  });
}
