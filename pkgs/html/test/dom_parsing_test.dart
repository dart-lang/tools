import 'package:html/dom_parsing.dart' show htmlToCodeMarkup;
import 'package:html/parser.dart' show parse;
import 'package:test/test.dart';

void main() {
  test(
      'htmlToCodeMarkup unescaped structural-name XSS DOCTYPE name reaches output unescaped',
      () {
    // Proves that you don't even need to call constructors; just parsing
    // a malicious string creates these nodes via WHATWG error recovery.
    var doc = parse('<!DOCTYPE x<img/src/onerror=alert(1)>');
    var code = htmlToCodeMarkup(doc);
    expect(code, isNot(contains('<img/src/onerror=alert(1)>')));
  });

  test(
      'htmlToCodeMarkup unescaped structural-name XSS attribute name reaches output unescaped',
      () {
    var doc = parse('<div <injected="v">text</div>');
    var code = htmlToCodeMarkup(doc);
    expect(
        code,
        isNot(
            contains('<code class="markup attribute-name"><injected</code>')));
  });

  test('htmlToCodeMarkup escapes script text contents for XSS protection', () {
    var doc = parse('<script><img src=x onerror=alert("XSS")></script>');
    var code = htmlToCodeMarkup(doc);
    expect(code, isNot(contains('<img')));
  });

  test('htmlToCodeMarkup escapes attribute values for XSS protection', () {
    var doc = parse('<div x="><script>alert(1)</script>">text</div>');
    var code = htmlToCodeMarkup(doc);
    expect(code, isNot(contains('<script>')));
  });
}
