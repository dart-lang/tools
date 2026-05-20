// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final excerpterPath = path.join('bin', 'excerpter.dart');

  test('no args', () {
    final process = Process.runSync(Platform.executable, [
      'run',
      excerpterPath,
    ]);

    expect(process.exitCode, equals(1));
  });

  test('invalid format', () {
    final process = Process.runSync(Platform.executable, [
      'run',
      excerpterPath,
      '-f-23-423-4',
    ]);

    expect(process.exitCode, equals(1));
  });

  test('options in README.md are in sync with CLI', () {
    final process = Process.runSync(Platform.executable, [
      'run',
      excerpterPath,
    ]);

    final stdout = process.stdout as String;
    // Extract option names from CLI output (e.g. --dry-run)
    final cliOptionNames = RegExp(
      r'^--([a-z-]+)',
      multiLine: true,
    ).allMatches(stdout).map((m) => m.group(1)!).toSet();

    expect(cliOptionNames, isNotEmpty);

    // Read option names from README.md
    final readmeFile = File('README.md');
    expect(readmeFile.existsSync(), isTrue);

    final readmeContent = readmeFile.readAsStringSync();
    // Match options like `| `--dry-run` |`
    final readmeOptionNames = RegExp(
      r'^\|\s*`--([a-z-]+)`\s*\|',
      multiLine: true,
    ).allMatches(readmeContent).map((m) => m.group(1)!).toSet();

    expect(readmeOptionNames, equals(cliOptionNames));
  });
}
