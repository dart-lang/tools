// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')
library;

import 'package:cli_config/cli_config.dart';
import 'package:test/test.dart';

void main() {
  test('path resolving windows', () {
    const path = 'C:\\foo\\bar\\';
    final workingDirectory = Uri.parse('file:///C:/baz/baf/');

    final config = Config(
      commandLineDefines: ['key=$path'],
      workingDirectory: workingDirectory,
    );
    final value = config.path('key', resolveUri: true);
    expect(value.toFilePath(), path);
  });
}
