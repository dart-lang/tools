// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'stats.dart' as stats;
import 'stats_lib.dart';
import 'update_shared.dart';

final _configs = [Config.commonMarkConfig, Config.gfmConfig];

Future<void> main() async {
  for (final config in _configs) {
    await _updateSpecFile(config);
  }
  await stats.main(['--update-files']);
}

Future<void> _updateSpecFile(Config config) async {
  final releaseUrl =
      'https://api.github.com/repos/${config.githubRepo}/releases/latest';
  final releaseJson = await downloadJson(releaseUrl) as Map<String, dynamic>;
  final tagName = releaseJson['tag_name'] as String;

  final specUrl =
      'https://raw.githubusercontent.com/${config.githubRepo}/$tagName/'
      '${config.specFilePath}';
  final specMarkdown = await downloadText(specUrl);
  final examples = parseSpecExamples(specMarkdown);

  final testFile = getTestsFile(config.prefix);
  print(
    'Updating ${testFile.path} from ${config.githubRepo}@$tagName '
    '(${examples.length} examples)',
  );
  const encoder = JsonEncoder.withIndent('  ');
  testFile.writeAsStringSync(
    '${encoder.convert(examples.map((e) => e.toJson()).toList())}\n',
  );
}
