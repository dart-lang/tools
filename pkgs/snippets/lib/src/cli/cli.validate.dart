// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cli.dart';

final class _ValidateCommand extends _Base {
  _ValidateCommand({required super.out, required super.err});

  @override
  String get name => 'validate';

  @override
  String get description =>
      'Check that the code samples in markdown files are up to date, without '
      'changing anything.';

  @override
  int run() {
    final outcome = updateDirectory(directory: directory, write: false);
    final failed = report(outcome.diagnostics);

    for (final MapEntry(key: file, value: count) in outcome.stale.entries) {
      err.writeln('$file: error: $count code '
          '${count == 1 ? 'block is' : 'blocks are'} out of date; run '
          '`dart run snippets@ update`');
    }
    if (outcome.stale.isEmpty && !failed) {
      out.writeln('${outcome.scanned} markdown files are up to date');
    }
    return failed || outcome.stale.isNotEmpty ? 1 : 0;
  }
}
