// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

import 'package:args/args.dart';
import 'package:sigstore/src/hook_helpers/builder.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'os',
      abbr: 'o',
      allowed: ['linux', 'macos', 'windows', 'all', 'auto'],
      defaultsTo: 'auto',
      help: 'Target OS family to build for.',
    )
    ..addOption(
      'compile-type',
      abbr: 'c',
      allowed: ['dynamic', 'static', 'both'],
      defaultsTo: 'both',
      help: 'Library type to produce.',
    )
    ..addOption(
      'target',
      abbr: 't',
      help: 'Specific target triple to build.',
    )
    ..addOption(
      'out-dir',
      abbr: 'd',
      defaultsTo: 'bin',
      help: 'Output directory for built binaries.',
    );

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Error parsing arguments: $e\n');
    stderr.writeln(parser.usage);
    exit(1);
  }

  final packageRoot = Platform.script.resolve('../');
  final rustDir = Directory.fromUri(packageRoot.resolve('rust/'));
  final outDir = Directory.fromUri(
    packageRoot.resolve('${results['out-dir']}/'),
  );
  await outDir.create(recursive: true);

  final List<String> targetsToBuild;
  if (results['target'] != null) {
    targetsToBuild = [results['target'] as String];
  } else {
    var os = results['os'] as String;
    if (os == 'auto') {
      if (Platform.isLinux) {
        os = 'linux';
      } else if (Platform.isMacOS) {
        os = 'macos';
      } else if (Platform.isWindows) {
        os = 'windows';
      } else {
        os = 'all';
      }
    }

    targetsToBuild = switch (os) {
      'linux' => linuxTargets,
      'macos' => macosTargets,
      'windows' => windowsTargets,
      'all' => allTargets,
      _ => linuxTargets,
    };
  }

  final compileType = results['compile-type'] as String;
  final staticModes = switch (compileType) {
    'dynamic' => [false],
    'static' => [true],
    _ => [false, true],
  };

  print(
    '==> Precompiling Sigstore binaries for '
    '${targetsToBuild.length} targets...',
  );

  for (final target in targetsToBuild) {
    for (final isStatic in staticModes) {
      final libType = isStatic ? 'static' : 'dynamic';
      final outFileName = 'libsigstore_ffi-$libType-$target';
      final outFile = File('${outDir.path}/$outFileName');

      try {
        await buildRustLibrary(
          rustDir: rustDir,
          target: target,
          isStatic: isStatic,
          outputPath: outFile.path,
        );
        print('Successfully built $outFileName');
      } catch (e) {
        stderr.writeln('Warning: Build for $target ($libType) failed: $e');
      }
    }
  }

  print('==> Precompilation complete. Output at ${outDir.path}');
}
