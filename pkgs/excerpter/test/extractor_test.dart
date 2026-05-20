// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:excerpter/src/extract.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('ExcerptExtractor exceptional cases', () {
    final extractor = ExcerptExtractor();

    test('missing file throws ExtractException', () async {
      final nonexistentPath = path.join(d.sandbox, 'nonexistent.dart');
      expect(
        () => extractor.extractRegion(nonexistentPath, 'my-region'),
        throwsA(
          isA<ExtractException>().having(
            (e) => e.toString(),
            'toString()',
            contains('No file exists at'),
          ),
        ),
      );
    });

    test('missing region throws ExtractException', () async {
      await d.file('simple.dart', '''
// #docregion existing-region
void main() {}
// #enddocregion existing-region
''').create();

      final filePath = path.join(d.sandbox, 'simple.dart');
      expect(
        () => extractor.extractRegion(filePath, 'nonexistent-region'),
        throwsA(
          isA<ExtractException>().having(
            (e) => e.toString(),
            'toString()',
            contains('does not exist in the file at'),
          ),
        ),
      );
    });

    test(
      'empty region name throws ExtractException with rich span format',
      () async {
        await d.file('empty_region.dart', '''
// #docregion a,,b
void main() {}
// #enddocregion a,,b
''').create();

        final filePath = path.join(d.sandbox, 'empty_region.dart');
        expect(
          () => extractor.extractRegion(filePath, 'a'),
          throwsA(
            isA<ExtractException>()
                .having(
                  (e) => e.message,
                  'message',
                  'docregion comment tried to use an empty region name.',
                )
                .having((e) => e.span?.text, 'span.text', '// #docregion a,,b')
                .having((e) => e.span?.start.line, 'span.start.line', 0)
                .having((e) => e.span?.start.column, 'span.start.column', 0),
          ),
        );
      },
    );

    test('unopened enddocregion throws ExtractException', () async {
      await d.file('unopened.dart', '''
void main() {}
// #enddocregion my-region
''').create();

      final filePath = path.join(d.sandbox, 'unopened.dart');
      expect(
        () => extractor.extractRegion(filePath, 'my-region'),
        throwsA(
          isA<ExtractException>().having(
            (e) => e.toString(),
            'toString()',
            contains(
              "enddocregion tried to close the unopened 'my-region' region",
            ),
          ),
        ),
      );
    });

    test('unclosed docregion throws ExtractException', () async {
      await d.file('unclosed.dart', '''
// #docregion my-region
void main() {}
''').create();

      final filePath = path.join(d.sandbox, 'unclosed.dart');
      expect(
        () => extractor.extractRegion(filePath, 'my-region'),
        throwsA(
          isA<ExtractException>().having(
            (e) => e.toString(),
            'toString()',
            contains('Regions {my-region} were not closed'),
          ),
        ),
      );
    });

    test('does not match docregion patterns embedded inside string literals or '
        'normal code', () async {
      await d.file('non_comment.dart', '''
void main() {
  final stringPattern = "not a comment #docregion my-region";
  print(stringPattern);
  final anotherPattern = "not a comment #enddocregion my-region";
}
''').create();

      final filePath = path.join(d.sandbox, 'non_comment.dart');
      final region = await extractor.extractRegion(filePath, '');
      final lines = region.linesWithPlaster(null).toList();
      expect(lines, anyElement(contains('not a comment #docregion my-region')));
    });

    test(
      'does not match docregion patterns inside multiline strings',
      () async {
        await d.file('multiline_string.dart', '''
void main() {
  final multiline = """
  This is a multiline string
  #docregion my-region
  that spans lines.
  #enddocregion my-region
  """;
}
''').create();

        final filePath = path.join(d.sandbox, 'multiline_string.dart');
        final region = await extractor.extractRegion(filePath, '');
        final lines = region.linesWithPlaster(null).toList();
        expect(lines, anyElement(contains('#docregion my-region')));
      },
    );

    test('supports other dialects (Python, HTML, CSS) correctly', () async {
      await d.file('sample.py', '''
# #docregion py-region
print("hello")
# #enddocregion py-region
''').create();

      await d.file('sample.html', '''
<!-- #docregion html-region -->
<div>Hello</div>
<!-- #enddocregion html-region -->
''').create();

      await d.file('sample.css', '''
/* #docregion css-region */
body { color: red; }
/* #enddocregion css-region */
''').create();

      final pyPath = path.join(d.sandbox, 'sample.py');
      final htmlPath = path.join(d.sandbox, 'sample.html');
      final cssPath = path.join(d.sandbox, 'sample.css');

      final pyRegion = await extractor.extractRegion(pyPath, 'py-region');
      expect(
        pyRegion.linesWithPlaster(null),
        contains(contains('print("hello")')),
      );

      final htmlRegion = await extractor.extractRegion(htmlPath, 'html-region');
      expect(
        htmlRegion.linesWithPlaster(null),
        contains(contains('<div>Hello</div>')),
      );

      final cssRegion = await extractor.extractRegion(cssPath, 'css-region');
      expect(
        cssRegion.linesWithPlaster(null),
        contains(contains('body { color: red; }')),
      );
    });
  });
}
