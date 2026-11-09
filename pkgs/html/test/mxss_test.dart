import 'package:html/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Mutation XSS Prevention (Namespace-aware raw-text serialization)', () {
    void verifySafeSerialization(String outerTag, String innerTag) {
      test('Escapes < inside <$outerTag><$innerTag>', () {
        final payload = '&lt;img src=x onerror=alert(1)&gt;';
        final input = '<$outerTag><$innerTag>$payload</$innerTag></$outerTag>';
        final doc = parse(input);

        final output = doc.body!.innerHtml;

        // Output must retain &lt; and &gt; escaped
        expect(
            output, '<$outerTag><$innerTag>$payload</$innerTag></$outerTag>');

        // Ensure that a reparse doesn't mutate it into a live <img> tag
        final reparsedDoc = parse(output);
        expect(reparsedDoc.querySelector('img'), isNull,
            reason: 'img should remain escaped text');
      });
    }

    verifySafeSerialization('svg', 'style');
    verifySafeSerialization('svg', 'iframe');
    verifySafeSerialization('svg', 'xmp');

    verifySafeSerialization('math', 'style');
    verifySafeSerialization('math', 'iframe');
    verifySafeSerialization('math', 'xmp');

    for (final outerTag in ['svg', 'math']) {
      for (final endTag in ['</p>', '</br>']) {
        test('$endTag exits <$outerTag> before subsequent <style>', () {
          final input =
              '<$outerTag>$endTag<style><!--</style><img src=x onerror=alert(1)>--></style></$outerTag>';
          final doc = parse(input);
          // Initial parse already breaks out of foreign content, matching
          // browsers so <img> is exposed on the first parse rather than only
          // appearing after innerHtml re-serialization.
          expect(doc.querySelectorAll('img'), hasLength(1));
        });
      }
    }

    test('Escapes < and > in attribute values', () {
      final doc = parse(
        '<svg><style><a id="</style><img src=x onerror=alert(1)>"></svg>',
      );
      final output = doc.body!.innerHtml;
      expect(
        output,
        '<svg><style>'
        '<a id="&lt;/style&gt;&lt;img src=x onerror=alert(1)&gt;"></a>'
        '</style></svg>',
      );
      expect(parse(output).querySelector('img'), isNull);
    });
  });
}
