// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';

import '../tool/expected_output.dart';
import '../tool/stats_lib.dart';

void main() {
  test('parseSpecExamples extracts examples and skips disabled ones', () {
    const spec = '''
# Tabs <!-- comment -->

```````````````````````````````` example
→foo
.
<pre><code>foo
</code></pre>
````````````````````````````````

# Strikethrough (extension)

```````````````````````````````` example strikethrough
~~Hi~~
.
<p><del>Hi</del></p>
````````````````````````````````

```````````````````````````````` example disabled
ignored
.
<p>ignored</p>
````````````````````````````````
''';

    final examples = parseSpecExamples(spec);
    expect(examples, hasLength(2));

    expect(examples[0].example, 1);
    expect(examples[0].section, 'Tabs');
    expect(examples[0].markdown, '\tfoo\n');
    expect(examples[0].html, '<pre><code>foo\n</code></pre>\n');
    expect(examples[0].extensions, isEmpty);
    expect(examples[0].toJson().containsKey('extensions'), isFalse);

    expect(examples[1].example, 2);
    expect(examples[1].section, 'Strikethrough (extension)');
    expect(examples[1].markdown, '~~Hi~~\n');
    expect(examples[1].html, '<p><del>Hi</del></p>\n');
    expect(examples[1].extensions, {'strikethrough'});
    expect(examples[1].toJson()['extensions'], ['strikethrough']);
  });

  test('parseSpecExamples throws FormatException on malformed examples', () {
    expect(
      () => parseSpecExamples(
        '```````````````````````````````` example\nfoo\n'
        '````````````````````````````````\n',
      ),
      throwsFormatException,
    );
    expect(
      () => parseSpecExamples(
        '```````````````````````````````` example\nfoo\n.\n<p>foo</p>\n',
      ),
      throwsFormatException,
    );
  });

  for (final prefix in ['common_mark', 'gfm']) {
    test('$prefix unit files and stats are in sync with spec tests', () {
      final sections = loadCommonMarkSections(prefix);
      final statsJson =
          jsonDecode(getStatsFile(prefix).readAsStringSync())
              as Map<String, dynamic>;

      final specExamplesByHeader = <String, CommonMarkTestCase>{};
      final statsLevelByHeader = <String, String?>{};

      for (final entry in sections.entries) {
        final sectionStats = statsJson[entry.key] as Map<String, dynamic>?;
        expect(
          sectionStats,
          isNotNull,
          reason:
              'Missing section "${entry.key}" in tool/${prefix}_stats.json. '
              'Run `dart run tool/stats.dart --update-files`.',
        );
        for (final testCase in entry.value) {
          final header = testCase.toString();
          specExamplesByHeader[header] = testCase;
          statsLevelByHeader[header] =
              sectionStats![testCase.example.toString()] as String?;
        }
      }

      final unitCases = dataCasesUnder(testDirectory: prefix).toList();
      expect(
        unitCases.length,
        specExamplesByHeader.length,
        reason:
            'test/$prefix/*.unit has ${unitCases.length} cases, but '
            'tool/${prefix}_tests.json has ${specExamplesByHeader.length}. '
            'Do not hand-edit generated files in test/$prefix/; add custom '
            'tests to test/extensions/ or test/original/ and run '
            '`dart run tool/stats.dart --update-files`.',
      );

      for (final dataCase in unitCases) {
        final colonIndex = dataCase.description.indexOf(': ');
        final header = colonIndex == -1
            ? dataCase.description
            : dataCase.description.substring(colonIndex + 2);
        final specCase = specExamplesByHeader[header];
        expect(
          specCase,
          isNotNull,
          reason:
              'Unexpected test case "$header" in '
              'test/${dataCase.directory}/${dataCase.file}.unit. '
              'Run `dart run tool/stats.dart --update-files`.',
        );
        expect(
          dataCase.input,
          specCase!.markdown,
          reason:
              'Input mismatch for "$header" in '
              'test/${dataCase.directory}/${dataCase.file}.unit. '
              'Run `dart run tool/stats.dart --update-files`.',
        );

        final isStrict = dataCase.expectedOutput == specCase.html;
        final recordedLevel = statsLevelByHeader[header];
        expect(
          recordedLevel == 'strict',
          isStrict,
          reason:
              'Stats mismatch for "$header" in tool/${prefix}_stats.json '
              '(recorded "$recordedLevel", strict match: $isStrict). '
              'Run `dart run tool/stats.dart --update-files`.',
        );
      }
    });
  }
}
