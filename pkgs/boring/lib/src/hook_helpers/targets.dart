// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_assets/code_assets.dart';

/// The GitHub repository whose releases have the prebuilt libraries.
const releaseRepository = 'mosuem/boring';

/// The prefix of the tag of the release with the prebuilt libraries for a
/// version, see [releaseAssetUrl].
const releaseTagPrefix = 'v';

/// The targets that `.github/workflows/boring_binaries.yaml` builds the
/// prebuilt libraries for.
///
/// The `fetch` build mode compiles BoringSSL from source for all other
/// targets. Keep in sync with the matrix of the `precompile` job.
const prebuiltTargets = <(OS, Architecture, IOSSdk?)>[
  (OS.linux, Architecture.arm64, null),
  (OS.linux, Architecture.x64, null),
  (OS.macOS, Architecture.arm64, null),
  (OS.macOS, Architecture.x64, null),
  (OS.windows, Architecture.x64, null),
];

/// The URL of the release asset [assetName] of the release [version].
Uri releaseAssetUrl(String version, String assetName) => Uri.parse(
  'https://github.com/$releaseRepository/releases/download/'
  '$releaseTagPrefix$version/$assetName',
);

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
