// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:excerpter/excerpter.dart';

void main() async {
  // #docregion main
  // Initialize the updater pointing to a source folder of code assets
  final updater = Updater(
    baseSourcePath: 'lib',
    validTargetExtensions: {'.md'},
  );

  // Run the updater on a markdown file or directory (in dry-run mode
  // by default)
  final result = await updater.update('README.md', makeUpdates: false);

  print('Processed ${result.filesVisited} files.');
  print('Visited ${result.excerptsVisited} excerpts.');
  // #enddocregion main
}
