// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:hooks/hooks.dart' show BuildError, HookInputUserDefines;

/// How `hook/build.dart` obtains the BoringSSL library, see the README.
enum BuildModeEnum {
  /// Downloads the prebuilt library of the pinned release, and compiles
  /// BoringSSL from source if there is none for the target.
  fetch,

  /// Compiles BoringSSL from the vendored source with CMake.
  checkout,

  /// Bundles the dynamic library at `localPath` as is.
  local,
}

/// The options under `hooks.user_defines.boring` in the pubspec.yaml of the
/// root package.
class BuildOptions {
  final BuildModeEnum buildMode;
  final Uri? localPath;

  BuildOptions({required this.buildMode, this.localPath});

  /// Throws a [BuildError] if `buildMode` is not one of [BuildModeEnum], so a
  /// typo doesn't silently download prebuilt binaries instead of building from
  /// source.
  factory BuildOptions.fromDefines(HookInputUserDefines defines) =>
      BuildOptions(
        buildMode: parseBuildMode(defines['buildMode']),
        localPath: defines.path('localPath'),
      );

  /// Parses the `buildMode` user-define [value], defaulting to
  /// [BuildModeEnum.fetch] if it is `null`.
  static BuildModeEnum parseBuildMode(Object? value) {
    if (value == null) return BuildModeEnum.fetch;
    final mode = value is String
        ? BuildModeEnum.values.where((mode) => mode.name == value).firstOrNull
        : null;
    if (mode == null) {
      final valid = BuildModeEnum.values.map((mode) => '`${mode.name}`');
      throw BuildError(
        message:
            'Unknown boring `buildMode` ${_describe(value)} under '
            '`hooks.user_defines.boring` in pubspec.yaml. '
            'Expected one of ${valid.join(', ')}.',
      );
    }
    return mode;
  }

  static String _describe(Object value) =>
      value is String ? "'$value'" : '$value (${value.runtimeType})';

  @override
  String toString() =>
      'BuildOptions(buildMode: ${buildMode.name}, localPath: $localPath)';
}
