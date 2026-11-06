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

  test('parse() limits elementInScope backwards scan', () async {
    final payloadStr = '<div>' * 50000;

    // This will reliably timeout on unpatched versions because Isolate.run
    // frees the main event loop to trigger the test framework's timer.
    final (outerHtmlLength, bodyText) = await Isolate.run(() {
      final doc = parse(payloadStr);
      return (doc.outerHtml.length, doc.body!.text);
    });
    expect(outerHtmlLength, greaterThan(payloadStr.length));
    expect(bodyText, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('parse() clamps DOM tree depth while preserving balanced ancestor tags',
      () {
    final doc = parse(
      '<div id="outer">${'<div>' * 600}hello${'</div>' * 600}'
      '<span id="after">world</span></div>',
    );
    expect(doc.querySelector('#outer > #after')?.text, 'world');
    expect(doc.body!.text, 'helloworld');
  });
}
