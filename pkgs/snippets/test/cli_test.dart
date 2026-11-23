// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The CLI, run against a real package in a temporary directory.
///
/// Everything below this is unit tested against strings; these tests exist to
/// catch the things only a filesystem can get wrong — which files are found,
/// which package root each one resolves against, what is written, and what
/// the exit code is.
library;

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:snippets/src/cli/cli.dart';
import 'package:test/scaffolding.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  setUp(() async {
    await d.file('pubspec.yaml', 'name: demo\n').create();
  });

  test('update updates a stale document', () async {
    await d.dir('example', [
      d.file('hello.dart', "void main() {\n  print('hi');\n}\n"),
    ]).create();
    await d
        .file('README.md', '```dart @example example/hello.dart\n```\n')
        .create();

    final out = StringBuffer();
    await check(runSnippets(['update', '-C', d.sandbox], out: out))
        .completes((it) => it.equals(0));

    check(out.toString()).contains('updated README.md');
    await d.file('README.md', '''
```dart @example example/hello.dart
void main() {
  print('hi');
}
```
''').validate();
  });

  test('update --dry-run reports stale files without writing them', () async {
    await d.dir('example', [
      d.file('hello.dart', 'void main() {}\n'),
    ]).create();
    const stale = '```dart @example example/hello.dart\n```\n';
    await d.file('README.md', stale).create();

    final out = StringBuffer();
    await check(
      runSnippets(['update', '--dry-run', '-C', d.sandbox], out: out),
    ).completes((it) => it.equals(0));

    check(out.toString()).contains('would update README.md');
    await d.file('README.md', stale).validate();
  });

  test('update is quiet when everything is up to date', () async {
    await d.file('README.md', '# nothing to do\n').create();
    final out = StringBuffer();
    await check(runSnippets(['update', '-C', d.sandbox], out: out))
        .completes((it) => it.equals(0));
    check(out.toString()).contains('1 markdown file is up to date');
  });

  test('validate fails on a stale document and changes nothing', () async {
    await d.dir('example', [
      d.file('hello.dart', 'void main() {}\n'),
    ]).create();
    const stale = '```dart @example example/hello.dart\nold;\n```\n';
    await d.file('README.md', stale).create();

    final err = StringBuffer();
    await check(runSnippets(['validate', '-C', d.sandbox], err: err))
        .completes((it) => it.equals(1));

    check(err.toString()).contains('out of date');
    await d.file('README.md', stale).validate();
  });

  test('validate passes once the document is updated', () async {
    await d.dir('example', [
      d.file('hello.dart', 'void main() {}\n'),
    ]).create();
    await d
        .file('README.md', '```dart @example example/hello.dart\n```\n')
        .create();

    await check(runSnippets(['update', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await check(runSnippets(['validate', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
  });

  test('errors are reported and fail the command', () async {
    await d
        .file('README.md', '```dart @example example/missing.dart\n```\n')
        .create();
    final err = StringBuffer();
    await check(runSnippets(['update', '-C', d.sandbox], err: err))
        .completes((it) => it.equals(1));
    check(err.toString())
      ..contains('README.md')
      ..contains('missing.dart');
  });

  test('a nested package resolves against its own package root', () async {
    // `example/app/` is a package of its own, so `/hello.dart` in its
    // documentation means `example/app/hello.dart`, not `hello.dart`.
    await d.file('hello.dart', 'outer;\n').create();
    await d.dir('example', [
      d.dir('app', [
        d.file('pubspec.yaml', 'name: demo_app\n'),
        d.file('hello.dart', 'inner;\n'),
        d.file('README.md', '```dart @example /hello.dart\n```\n'),
      ]),
    ]).create();

    await check(runSnippets(['update', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await d.dir('example', [
      d.dir('app', [
        d.file('README.md', '```dart @example /hello.dart\ninner;\n```\n'),
      ]),
    ]).validate();
  });

  test('workspace member packages resolve against their own package root',
      () async {
    await d.file('hello.dart', 'outer;\n').create();
    await d.dir('pkgs', [
      d.dir('a', [
        d.file('pubspec.yaml', 'name: pkg_a\n'),
        d.file('hello.dart', 'inner;\n'),
        d.file('README.md', '```dart @example /hello.dart\n```\n'),
      ]),
    ]).create();

    await check(runSnippets(['update', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await d.dir('pkgs', [
      d.dir('a', [
        d.file('README.md', '```dart @example /hello.dart\ninner;\n```\n'),
      ]),
    ]).validate();

    await d
        .file(
            'pkgs/a/README.md', '```dart @example /hello.dart#unclosed\n```\n')
        .create();
    await d.file('pkgs/a/hello.dart', '// #region unclosed\n').create();
    final err = StringBuffer();
    await check(runSnippets(['validate', '-C', d.sandbox], err: err))
        .completes((it) => it.equals(1));
    check(err.toString()).contains(p.join('pkgs', 'a', 'hello.dart'));
  });

  test('relative references work without pubspec.yaml; leading / requires one',
      () async {
    // Only safe if `d.sandbox` itself has no enclosing `pubspec.yaml` either:
    d.file('pubspec.yaml').io.deleteSync();

    await d.dir('no_pubspec', [
      d.file('hello.dart', 'ok;\n'),
      d.file('README.md', '```dart @example hello.dart\n```\n'),
    ]).create();
    final root = d.path('no_pubspec');

    await check(runSnippets(['update', '-C', root], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await d
        .file('no_pubspec/README.md', '```dart @example hello.dart\nok;\n```\n')
        .validate();

    await d
        .file(
          'no_pubspec/README.md',
          '# Intro\n\n```dart @example /hello.dart\n```\n',
        )
        .create();
    final err = StringBuffer();
    await check(runSnippets(['validate', '-C', root], err: err))
        .completes((it) => it.equals(1));
    check(err.toString())
      ..contains('line 3')
      ..contains('pubspec.yaml');
  });

  test('skips non-UTF-8 markdown files and rejects binary targets', () async {
    await d.file('latin1.md', [0xff, 0xfe]).create();
    await d.file('README.md', '# ok\n').create();

    final err = StringBuffer();
    await check(
      runSnippets(['validate', '-C', d.sandbox], out: StringBuffer(), err: err),
    ).completes((it) => it.equals(0));
    check(err.toString())
      ..contains('Warning:')
      ..contains('latin1.md');

    await d.file('logo.bin', [0x89, 0x50, 0x4e, 0x47, 0xff]).create();
    await d.file('README.md', '```text @example logo.bin\n```\n').create();
    err.clear();
    await check(
      runSnippets(['validate', '-C', d.sandbox], out: StringBuffer(), err: err),
    ).completes((it) => it.equals(1));
    check(err.toString())
      ..contains('README.md')
      ..contains('not valid UTF-8');
  });

  test('ignores markdown files in hidden directories', () async {
    await d.file('a.dart', 'void main() {}\n').create();
    const stale = '```dart @example ../a.dart\n```\n';
    await d.dir('.dart_tool', [d.file('stale.md', stale)]).create();

    await check(runSnippets(['validate', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await check(runSnippets(['update', '-C', d.sandbox], out: StringBuffer()))
        .completes((it) => it.equals(0));
    await d.dir('.dart_tool', [d.file('stale.md', stale)]).validate();
  });

  test('-C may come before the command', () async {
    await d.file('README.md', '# hello\n').create();
    await check(runSnippets(['-C', d.sandbox, 'validate'], out: StringBuffer()))
        .completes((it) => it.equals(0));
  });

  test('a directory that does not exist is an error', () async {
    await check(
      runSnippets(['validate', '-C', d.path('nope')], err: StringBuffer()),
    ).completes((it) => it.equals(1));
  });

  test('an unknown command is a usage error', () async {
    await check(runSnippets(['nonsense'], err: StringBuffer()))
        .completes((it) => it.equals(64));
  });

  test('an unexpected positional argument is a usage error', () async {
    for (final cmd in ['update', 'validate']) {
      await check(runSnippets([cmd, 'doc/'], err: StringBuffer()))
          .completes((it) => it.equals(64));
    }
  });
}
