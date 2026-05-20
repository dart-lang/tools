// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:excerpter/excerpter.dart';
import 'package:excerpter/src/inject.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Injection exceptional cases', () {
    test('invalid code excerpt syntax throws InjectionException '
        'with rich span format', () async {
      await d.file('test.md', '''
<?code-excerpt invalid syntax
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>()
              .having(
                (e) => e.message,
                'message',
                'Invalid code excerpt syntax.',
              )
              .having(
                (e) => e.span?.text,
                'span.text',
                '<?code-excerpt invalid syntax',
              )
              .having((e) => e.span?.start.line, 'span.start.line', 0)
              .having((e) => e.span?.start.column, 'span.start.column', 0),
        ),
      );
    });

    test(
      'inject instruction followed by EOF throws InjectionException',
      () async {
        await d.file('test.md', '''
<?code-excerpt "code.dart" ?>
''').create();

        final fileUpdater = FileUpdater(
          path.join(d.sandbox, 'test.md'),
          baseSourcePath: d.sandbox,
          defaultPlasterContent: '...',
          defaultTransforms: const [],
        );

        expect(
          fileUpdater.process,
          throwsA(
            isA<InjectionException>().having(
              (e) => e.toString(),
              'toString()',
              contains(
                'An inject instruction must be followed by a code block.',
              ),
            ),
          ),
        );
      },
    );

    test(
      'inject instruction followed by non-codeblock throws InjectionException',
      () async {
        await d.file('test.md', '''
<?code-excerpt "code.dart" ?>
Some random line
''').create();

        final fileUpdater = FileUpdater(
          path.join(d.sandbox, 'test.md'),
          baseSourcePath: d.sandbox,
          defaultPlasterContent: '...',
          defaultTransforms: const [],
        );

        expect(
          fileUpdater.process,
          throwsA(
            isA<InjectionException>().having(
              (e) => e.toString(),
              'toString()',
              contains(
                'An inject instruction must be followed by a code block '
                'with a language specified.',
              ),
            ),
          ),
        );
      },
    );

    test('unmatched code block close throws InjectionException', () async {
      await d.file('test.md', '''
<?code-excerpt "code.dart" ?>
```dart
void main() {}
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>().having(
            (e) => e.toString(),
            'toString()',
            contains('Unclosed or unmatched code block.'),
          ),
        ),
      );
    });

    test(
      'set instruction with multiple arguments throws InjectionException',
      () async {
        await d.file('test.md', '''
<?code-excerpt path-base="a" plaster="..." ?>
''').create();

        final fileUpdater = FileUpdater(
          path.join(d.sandbox, 'test.md'),
          baseSourcePath: d.sandbox,
          defaultPlasterContent: '...',
          defaultTransforms: const [],
        );

        expect(
          fileUpdater.process,
          throwsA(
            isA<InjectionException>().having(
              (e) => e.toString(),
              'toString()',
              contains(
                'A set instruction must have only one argument specified.',
              ),
            ),
          ),
        );
      },
    );

    test(
      'set instruction with unsupported argument throws InjectionException',
      () async {
        await d.file('test.md', '''
<?code-excerpt unsupported="val" ?>
''').create();

        final fileUpdater = FileUpdater(
          path.join(d.sandbox, 'test.md'),
          baseSourcePath: d.sandbox,
          defaultPlasterContent: '...',
          defaultTransforms: const [],
        );

        expect(
          fileUpdater.process,
          throwsA(
            isA<InjectionException>().having(
              (e) => e.toString(),
              'toString()',
              contains(
                'A set instruction can only specify the `path-base`, '
                '`plaster`, and `replace` arguments.',
              ),
            ),
          ),
        );
      },
    );

    test('duplicate indent-by argument throws InjectionException '
        'with pinpoint sub-span', () async {
      await d.file('test.md', '''
<?code-excerpt "code.dart" indent-by="2" indent-by="4" ?>
```dart
```
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>()
              .having(
                (e) => e.message,
                'message',
                'The `indent-by` argument can only be specified once '
                    'per instruction.',
              )
              .having((e) => e.span?.text, 'span.text', 'indent-by="4"')
              .having((e) => e.span?.start.line, 'span.start.line', 0)
              .having((e) => e.span?.start.column, 'span.start.column', 41)
              .having(
                (e) => e.toString(),
                'toString()',
                equals('''
Error on line 1, column 42 of ${path.join(d.sandbox, 'test.md')}: The `indent-by` argument can only be specified once per instruction.
  ╷
1 │ <?code-excerpt "code.dart" indent-by="2" indent-by="4" ?>
  │                                          ^^^^^^^^^^^^^
  ╵'''),
              ),
        ),
      );
    });

    test('duplicate plaster argument throws InjectionException', () async {
      await d.file('test.md', '''
<?code-excerpt "code.dart" plaster="..." plaster="none" ?>
```dart
```
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>().having(
            (e) => e.toString(),
            'toString()',
            contains(
              'The `plaster` argument can only be specified once '
              'per instruction.',
            ),
          ),
        ),
      );
    });

    test('negative indent-by throws InjectionException', () async {
      await d.file('test.md', '''
<?code-excerpt "code.dart" indent-by="-2" ?>
```dart
```
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>().having(
            (e) => e.toString(),
            'toString()',
            contains('The `indent-by` argument must be positive.'),
          ),
        ),
      );
    });

    test('unsupported inject argument throws InjectionException', () async {
      await d.file('test.md', '''
<?code-excerpt "code.dart" invalid-arg="foo" ?>
```dart
```
''').create();

      final fileUpdater = FileUpdater(
        path.join(d.sandbox, 'test.md'),
        baseSourcePath: d.sandbox,
        defaultPlasterContent: '...',
        defaultTransforms: const [],
      );

      expect(
        fileUpdater.process,
        throwsA(
          isA<InjectionException>().having(
            (e) => e.toString(),
            'toString()',
            contains('is an unsupported argument in inject instructions.'),
          ),
        ),
      );
    });

    test(
      'ignores code-excerpt instructions inside static code blocks',
      () async {
        await d.file('test.md', '''
Some markdown before.

```md
<?code-excerpt "nonexistent.dart" ?>
```

Some markdown after.
''').create();

        final fileUpdater = FileUpdater(
          path.join(d.sandbox, 'test.md'),
          baseSourcePath: d.sandbox,
          defaultPlasterContent: '...',
          defaultTransforms: const [],
        );

        final results = await fileUpdater.process();
        expect(results.warnings, hasLength(0));
        expect(results.excerptsVisited, equals(0));
        expect(results.needsUpdates, isFalse);
      },
    );
  });

  group('Updater exception and continueOnError behavior', () {
    test('continueOnError = false stops immediately on error', () async {
      await d.file('first.md', '''
<?code-excerpt "nonexistent.dart" ?>
```dart
```
''').create();

      await d.file('second.md', '''
Some normal content.
''').create();

      final updater = Updater(
        baseSourcePath: d.sandbox,
        validTargetExtensions: const {'.md'},
        continueOnError: false,
      );

      final results = await updater.update(d.sandbox, makeUpdates: false);
      expect(results.errors, hasLength(1));
      expect(results.filesVisited, equals(0));
    });

    test('continueOnError = true continues to next files on error', () async {
      await d.file('first.md', '''
<?code-excerpt "nonexistent.dart" ?>
```dart
```
''').create();

      await d.file('second.md', '''
Some normal content.
''').create();

      final updater = Updater(
        baseSourcePath: d.sandbox,
        validTargetExtensions: const {'.md'},
        continueOnError: true,
      );

      final results = await updater.update(d.sandbox, makeUpdates: false);
      expect(results.errors, hasLength(1));
      expect(results.filesVisited, equals(1));
    });
  });
}
