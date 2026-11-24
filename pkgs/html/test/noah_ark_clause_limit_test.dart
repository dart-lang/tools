@TestOn('vm')
library;

import 'dart:isolate';

import 'package:html/parser.dart' show parse;
import 'package:test/test.dart';

void main() {
  test('parse() limits active formatting element backwards scan', () async {
    final n = 50000;
    final payload = StringBuffer();
    for (var i = 0; i < n; i++) {
      payload.write('<b x=$i>');
    }

    final payloadStr = payload.toString();

    // This will reliably timeout on unpatched versions because Isolate.run
    // frees the main event loop to trigger the test framework's timer.
    await Isolate.run(() {
      parse(payloadStr);
    });
  }, timeout: const Timeout(Duration(seconds: 10)));
}
