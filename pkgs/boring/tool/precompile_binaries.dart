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
///
/// Builds for the current OS, or cross-compiles for iOS (on macOS, with Xcode)
/// and Android (with the NDK). The `precompile` job of
/// .github/workflows/boring_binaries.yaml builds every target in
/// `prebuiltTargets`.
void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'target-os',
      abbr: 'o',
      allowed: ['android', 'ios', 'linux', 'macos', 'windows', 'current'],
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
      'ios-sdk',
      abbr: 'i',
      allowed: IOSSdk.values.map((sdk) => sdk.type),
      help: 'The iOS SDK to build against. Required for iOS.',
    )
    ..addOption(
      'android-ndk',
      help:
          'The Android NDK to build with. Defaults to \$ANDROID_NDK_HOME, '
          '\$ANDROID_NDK_LATEST_HOME, \$ANDROID_NDK_ROOT, or the newest NDK in '
          '\$ANDROID_HOME/ndk.',
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

  final iosSdkType = results['ios-sdk'] as String?;
  final iosSdk = iosSdkType == null
      ? null
      : IOSSdk.values.firstWhere((sdk) => sdk.type == iosSdkType);
  if ((targetOS == OS.iOS) != (iosSdk != null)) {
    stderr.writeln(
      targetOS == OS.iOS
          ? '--ios-sdk is required for iOS.'
          : '--ios-sdk only applies to iOS.',
    );
    exit(1);
  }
  final androidNdk = targetOS == OS.android
      ? _androidNdk(results['android-ndk'] as String?)
      : null;

  final packageRoot = Platform.script.resolve('../');
  final outDir = Directory.fromUri(
    packageRoot.resolve('${results['out-dir']}/'),
  );
  await outDir.create(recursive: true);

  final targetTriple = targetTripleFor(targetOS, targetArch, iosSdk: iosSdk);
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
    if (targetOS == OS.macOS) ...[
      '-DCMAKE_OSX_ARCHITECTURES=${_appleArchitectures[targetArch]!}',
      // Without this, the libraries would only load on the macOS version of
      // the build machine or newer.
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${macOSDeploymentTargets[targetArch]!}',
    ],
    if (targetOS == OS.iOS) ...[
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_SYSROOT=${iosSdk!.type}',
      '-DCMAKE_OSX_ARCHITECTURES=${_appleArchitectures[targetArch]!}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${iOSDeploymentTarget(targetArch, iosSdk)}',
      // CMake's compiler checks build an executable, which iOS can't link
      // without an app bundle. The libraries themselves link fine.
      '-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY',
    ],
    if (targetOS == OS.android) ...[
      '-DCMAKE_TOOLCHAIN_FILE=${_androidToolchainFile(androidNdk!)}',
      '-DANDROID_ABI=${_androidAbis[targetArch]!}',
      '-DANDROID_PLATFORM=android-$androidMinApi',
      // 16 KB page alignment, which Android 15+ requires of native libraries.
      // The default since NDK r28; ignored by older NDKs, which the CI check
      // catches.
      '-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON',
    ],
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
    if (targetOS == OS.android) {
      // The NDK compiles with -g, which makes the libraries several times
      // larger. Keep the symbols of the static library for linking.
      await _run(_androidLlvmStrip(androidNdk!), [
        static ? '--strip-debug' : '--strip-unneeded',
        builtLibrary.path,
      ]);
    }
    final releaseAsset = File.fromUri(
      outDir.uri.resolve(
        releaseAssetName(targetOS, targetArch, iosSdk: iosSdk, static: static),
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

final _appleArchitectures = {
  Architecture.arm64: 'arm64',
  Architecture.x64: 'x86_64',
};

final _androidAbis = {
  Architecture.arm: 'armeabi-v7a',
  Architecture.arm64: 'arm64-v8a',
  Architecture.ia32: 'x86',
  Architecture.x64: 'x86_64',
  Architecture.riscv64: 'riscv64',
};

/// The oldest macOS version the prebuilt libraries run on.
///
/// Dart supports macOS 12 and Flutter's macOS deployment target defaults to
/// 10.15. Apple silicon Macs start at 11.0. The `precompile` job of
/// .github/workflows/boring_binaries.yaml checks the built libraries against
/// these, so keep them in sync with its `min-os` matrix entries.
final macOSDeploymentTargets = {
  Architecture.arm64: '11.0',
  Architecture.x64: '10.15',
};

/// The oldest iOS version the prebuilt libraries for [arch] and [sdk] run on.
///
/// 12.0 is native_toolchain_cmake's default for building from source, below
/// Flutter's minimum. The arm64 simulator only exists since iOS 14. Keep in
/// sync with the `min-os` matrix entries of the `precompile` job.
String iOSDeploymentTarget(Architecture arch, IOSSdk sdk) =>
    arch == Architecture.arm64 && sdk == IOSSdk.iPhoneSimulator
    ? '14.0'
    : '12.0';

/// The oldest Android API level the prebuilt libraries run on.
///
/// Flutter's minimum is 24, and BoringSSL doesn't need anything newer than
/// Android 5 (API 21), the oldest level NDK r26+ supports.
const androidMinApi = 21;

/// The Android NDK at [path], or the one the environment points at.
Uri _androidNdk(String? path) {
  final environment = Platform.environment;
  var ndk = path;
  for (final variable in [
    'ANDROID_NDK_HOME',
    'ANDROID_NDK_LATEST_HOME',
    'ANDROID_NDK_ROOT',
    'ANDROID_NDK',
  ]) {
    ndk ??= environment[variable];
  }
  if (ndk == null) {
    final home = environment['ANDROID_HOME'] ?? environment['ANDROID_SDK_ROOT'];
    final ndks = Directory('$home/ndk');
    if (home != null && ndks.existsSync()) {
      final versions = ndks.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (versions.isNotEmpty) ndk = versions.last.path;
    }
  }
  if (ndk == null ||
      !File('$ndk/build/cmake/android.toolchain.cmake').existsSync()) {
    stderr.writeln(
      'No Android NDK ${ndk == null ? 'found' : 'at $ndk'}. Pass --android-ndk '
      'or set ANDROID_NDK_HOME.',
    );
    exit(1);
  }
  stdout.writeln('==> Using the Android NDK at $ndk');
  return Directory(ndk).uri;
}

/// The CMake toolchain file of the Android NDK at [ndk].
String _androidToolchainFile(Uri ndk) =>
    ndk.resolve('build/cmake/android.toolchain.cmake').toFilePath();

/// The `llvm-strip` of the Android NDK at [ndk].
String _androidLlvmStrip(Uri ndk) {
  final hosts = Directory.fromUri(ndk.resolve('toolchains/llvm/prebuilt/'))
      .listSync()
      .whereType<Directory>();
  for (final host in hosts) {
    for (final name in ['llvm-strip', 'llvm-strip.exe']) {
      final strip = File.fromUri(host.uri.resolve('bin/$name'));
      if (strip.existsSync()) return strip.path;
    }
  }
  stderr.writeln('No llvm-strip in ${ndk.toFilePath()}.');
  exit(1);
}

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
