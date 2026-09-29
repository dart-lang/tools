// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

import 'package:args/args.dart';
import 'package:boring/src/hook_helpers/targets.dart';
import 'package:code_assets/code_assets.dart';

/// Builds the dynamic and the static library for a release.
///
/// hook/build.dart bundles the dynamic library when linking is disabled, and
/// hook/link.dart links the static library into a dynamic library with only
/// the functions an application uses when linking is enabled.
void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'target-os',
      abbr: 'o',
      allowed: ['linux', 'macos', 'windows', 'current'],
      defaultsTo: 'current',
      help: 'Target OS to build for.',
    )
    ..addOption(
      'target-arch',
      abbr: 'a',
      allowed: ['x64', 'arm64', 'arm', 'ia32', 'riscv64', 'current'],
      defaultsTo: 'current',
      help: 'Target architecture to build for.',
    )
    ..addOption(
      'out-dir',
      abbr: 'd',
      defaultsTo: 'bin',
      help: 'Output directory for built release binaries.',
    );

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Error parsing arguments: $e\n');
    stderr.writeln(parser.usage);
    exit(1);
  }

  final targetOS = results['target-os'] == 'current'
      ? OS.current
      : OS.values.firstWhere((o) => o.name == results['target-os']);

  final targetArch = results['target-arch'] == 'current'
      ? Architecture.current
      : Architecture.values.firstWhere((a) => a.name == results['target-arch']);

  final packageRoot = Platform.script.resolve('../');
  final outDir = Directory.fromUri(
    packageRoot.resolve('${results['out-dir']}/'),
  );
  await outDir.create(recursive: true);

  final targetTriple = targetTripleFor(targetOS, targetArch);
  stdout.writeln('==> Building BoringSSL for $targetTriple...');

  final buildDir = Directory.fromUri(
    packageRoot.resolve('build/precompile-$targetTriple/'),
  );
  final installDir = Directory.fromUri(buildDir.uri.resolve('install/'));
  await buildDir.create(recursive: true);

  await _run('cmake', [
    '-S',
    Directory.fromUri(packageRoot.resolve('src/')).path,
    '-B',
    buildDir.path,
    // The default generators: Visual Studio's on Windows, like
    // native_toolchain_cmake, which finds MSVC without a Developer Command
    // Prompt, and Makefiles elsewhere.
    if (targetOS == OS.windows) ...['-A', _visualStudioPlatforms[targetArch]!],
    if (targetOS == OS.macOS)
      '-DCMAKE_OSX_ARCHITECTURES=${_macOSArchitectures[targetArch]!}',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_INSTALL_PREFIX=${installDir.path}',
  ]);
  // Installs both libraries into installDir, see src/CMakeLists.txt.
  await _run('cmake', [
    '--build',
    buildDir.path,
    '--config',
    'Release',
    '--target',
    'install',
    '--parallel',
    '${Platform.numberOfProcessors}',
  ]);

  for (final static in [false, true]) {
    final builtLibrary = File.fromUri(
      installDir.uri.resolve(libraryFileName(targetOS, static: static)),
    );
    final releaseAsset = File.fromUri(
      outDir.uri.resolve(
        releaseAssetName(targetOS, targetArch, static: static),
      ),
    );
    await builtLibrary.copy(releaseAsset.path);
    stdout.writeln('==> Created release binary: ${releaseAsset.path}');
  }
}

final _visualStudioPlatforms = {
  Architecture.arm64: 'ARM64',
  Architecture.ia32: 'Win32',
  Architecture.x64: 'x64',
};

final _macOSArchitectures = {
  Architecture.arm64: 'arm64',
  Architecture.x64: 'x86_64',
};

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('==> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('$executable failed with exit code $exitCode');
    exit(exitCode);
  }
}
