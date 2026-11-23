// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'cli.dart';

final class _UpdateCommand extends _Base {
  _UpdateCommand({required super.out, required super.err}) {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Show which markdown files would be updated without writing them.',
    );
  }

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update the code samples in markdown files from the files they '
      'reference.';

  @override
  int run() {
    final dryRun = argResults!.flag('dry-run');
    final outcome = updateDirectory(directory: directory, write: !dryRun);
    final failed = report(outcome.diagnostics);

    final prefix = dryRun ? 'would update' : 'updated';
    for (final file in outcome.stale.keys) {
      out.writeln('$prefix $file');
    }
    if (outcome.stale.isEmpty && !failed) {
      out.writeln('${outcome.scanned} markdown files are up to date');
    }
    // Staleness is what this command is for, so only errors are failures.
    return failed ? 1 : 0;
  }
}
