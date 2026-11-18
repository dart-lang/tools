// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

void main() async {
  print('Generating Dart bindings from Rust bridge via Diplomat...');

  final packageRoot = Platform.script.resolve('../');
  var diplomatCargo = packageRoot.resolve('../diplomat/Cargo.toml');
  if (!File.fromUri(diplomatCargo).existsSync()) {
    diplomatCargo = packageRoot.resolve('../../diplomat/Cargo.toml');
  }
  final rustLib = packageRoot.resolve('rust/src/lib.rs');
  final outBindings = packageRoot.resolve('lib/src/bindings/');

  final diplomatCargoFile = File.fromUri(diplomatCargo);
  final List<String> cmd;
  final String executable;
  if (diplomatCargoFile.existsSync()) {
    executable = 'cargo';
    cmd = [
      'run',
      '--manifest-path',
      diplomatCargo.toFilePath(),
      '-p',
      'diplomat-tool',
      '--',
      'dart',
      outBindings.toFilePath(),
      '-e',
      rustLib.toFilePath(),
    ];
  } else {
    executable = 'diplomat-tool';
    cmd = [
      'dart',
      outBindings.toFilePath(),
      '-e',
      rustLib.toFilePath(),
    ];
  }

  final process = await Process.run(
    executable,
    cmd,
    workingDirectory: packageRoot.toFilePath(),
  );

  print(process.stdout);
  if (process.stderr.toString().isNotEmpty) {
    print(process.stderr);
  }

  if (process.exitCode != 0) {
    exit(process.exitCode);
  }

  print('Dart bindings generated successfully.');
}
