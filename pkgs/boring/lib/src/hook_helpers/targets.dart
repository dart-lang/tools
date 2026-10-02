// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_assets/code_assets.dart';

const supportedTargets = [
  (OS.android, Architecture.arm, null),
  (OS.android, Architecture.arm64, null),
  (OS.android, Architecture.ia32, null),
  (OS.android, Architecture.riscv64, null),
  (OS.android, Architecture.x64, null),
  (OS.iOS, Architecture.arm64, IOSSdk.iPhoneOS),
  (OS.iOS, Architecture.arm64, IOSSdk.iPhoneSimulator),
  (OS.iOS, Architecture.x64, IOSSdk.iPhoneSimulator),
  (OS.linux, Architecture.arm, null),
  (OS.linux, Architecture.arm64, null),
  (OS.linux, Architecture.ia32, null),
  (OS.linux, Architecture.riscv64, null),
  (OS.linux, Architecture.x64, null),
  (OS.macOS, Architecture.arm64, null),
  (OS.macOS, Architecture.x64, null),
  (OS.windows, Architecture.arm64, null),
  (OS.windows, Architecture.ia32, null),
  (OS.windows, Architecture.x64, null),
];

/// Formats a canonical target identifier, including [iosSdk] when targeting iOS
/// so device (`iphoneos`) and simulator (`iphonesimulator`) binaries do not
/// collide on `ios-arm64`.
String targetTripleFor(OS os, Architecture arch, {IOSSdk? iosSdk}) {
  if (os == OS.iOS && iosSdk != null) {
    return '${os.name}-${arch.name}-${iosSdk.type}';
  }
  return '${os.name}-${arch.name}';
}

/// The file name of the library built by `src/CMakeLists.txt` for [os].
///
/// The static library is linked into a dynamic library by `hook/link.dart`,
/// and the dynamic library is bundled as is when linking is disabled.
String libraryFileName(OS os, {required bool static}) => static
    ? os.staticlibFileName('bssl_dart_static')
    : os.dylibFileName('bssl_dart');

/// The name of the GitHub release asset with the prebuilt library for [os] and
/// [arch].
String releaseAssetName(
  OS os,
  Architecture arch, {
  IOSSdk? iosSdk,
  required bool static,
}) =>
    'boring-${targetTripleFor(os, arch, iosSdk: iosSdk)}-'
    '${libraryFileName(os, static: static)}';
