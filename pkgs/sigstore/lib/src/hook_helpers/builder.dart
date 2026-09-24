// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';
import 'package:code_assets/code_assets.dart';

const linuxTargets = [
  'x86_64-unknown-linux-gnu',
  'aarch64-unknown-linux-gnu',
  'armv7-unknown-linux-gnueabihf',
  'riscv64gc-unknown-linux-gnu',
  'aarch64-linux-android',
  'armv7-linux-androideabi',
  'x86_64-linux-android',
  'i686-linux-android',
];

const macosTargets = [
  'aarch64-apple-darwin',
  'x86_64-apple-darwin',
  'aarch64-apple-ios',
  'x86_64-apple-ios',
];

const windowsTargets = [
  'x86_64-pc-windows-msvc',
  'aarch64-pc-windows-msvc',
];

const allTargets = [
  ...linuxTargets,
  ...macosTargets,
  ...windowsTargets,
];

/// Converts Dart [CodeConfig] to Rust target triple.
String asRustTarget(CodeConfig code) {
  if (code.targetOS == OS.iOS &&
      code.targetArchitecture == Architecture.arm64 &&
      code.iOS.targetSdk == IOSSdk.iPhoneSimulator) {
    return 'aarch64-apple-ios-sim';
  }
  return switch ((code.targetOS, code.targetArchitecture)) {
    (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
    (OS.android, Architecture.arm64) => 'aarch64-linux-android',
    (OS.android, Architecture.ia32) => 'i686-linux-android',
    (OS.android, Architecture.riscv64) => 'riscv64-linux-android',
    (OS.android, Architecture.x64) => 'x86_64-linux-android',
    (OS.fuchsia, Architecture.arm64) => 'aarch64-unknown-fuchsia',
    (OS.fuchsia, Architecture.x64) => 'x86_64-unknown-fuchsia',
    (OS.iOS, Architecture.arm64) => 'aarch64-apple-ios',
    (OS.iOS, Architecture.x64) => 'x86_64-apple-ios',
    (OS.linux, Architecture.arm) => 'armv7-unknown-linux-gnueabihf',
    (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
    (OS.linux, Architecture.ia32) => 'i686-unknown-linux-gnu',
    (OS.linux, Architecture.riscv32) => 'riscv32gc-unknown-linux-gnu',
    (OS.linux, Architecture.riscv64) => 'riscv64gc-unknown-linux-gnu',
    (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
    (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
    (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
    (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
    (OS.windows, Architecture.ia32) => 'i686-pc-windows-msvc',
    (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
    (_, _) => throw UnimplementedError('Target $code not available for rust'),
  };
}

/// Core function to build the Sigstore Rust FFI library for a specific target.
Future<void> buildRustLibrary({
  required Directory rustDir,
  required String target,
  required bool isStatic,
  required String outputPath,
}) async {
  final manifestFile = File.fromUri(rustDir.uri.resolve('Cargo.toml'));
  if (!manifestFile.existsSync()) {
    throw ArgumentError(
      'The Cargo.toml file could not be found at ${manifestFile.path}',
    );
  }

  final crateType = isStatic ? 'staticlib' : 'cdylib';

  // Ensure output directory exists
  final outFile = File(outputPath);
  await outFile.parent.create(recursive: true);

  await runProcess(
    'cargo',
    [
      'rustc',
      '--manifest-path',
      manifestFile.path,
      '--crate-type=$crateType',
      '--release',
      '--target=$target',
      '--',
      '--emit',
      'link=${outFile.path}',
    ],
    workingDirectory: rustDir,
  );
}

/// Helper to execute an external process and stream error details on failure.
Future<void> runProcess(
  String executable,
  List<String> arguments, {
  Directory? workingDirectory,
}) async {
  final processResult = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory?.path,
  );
  if (processResult.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'stdout:\n${processResult.stdout}\nstderr:\n${processResult.stderr}',
      processResult.exitCode,
    );
  }
}
