// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utilities to locate the Dart SDK.
library;

import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

export 'src/base_directories.dart';

/// The path to the root of the Dart SDK, or `null` if no SDK could be located.
///
/// Probes the host environment across four tiers (memoized on first access):
/// 1. `Platform.resolvedExecutable` (active JIT VM runtime)
/// 2. `DART_ROOT` and `DART_SDK` environment variables
/// 3. `PATH` environment variable traversal (dereferencing symlinks and
///    checking Flutter cache layouts)
/// 4. `FLUTTER_ROOT/bin/cache/dart-sdk` fallback
String? get sdkPath {
  if (Zone.current[environmentOverridesKey] != null) {
    return _resolveSdkPath();
  }
  if (!_sdkPathResolved) {
    _cachedSdkPath = _resolveSdkPath();
    _sdkPathResolved = true;
  }
  return _cachedSdkPath;
}

String? _cachedSdkPath;
bool _sdkPathResolved = false;

/// The path to the `dart` executable, or `null` if no executable could be
/// located.
///
/// If a valid [sdkPath] is found, returns `<sdkPath>/bin/dart` (`dart.exe` on
/// Windows). Otherwise, attempts direct `PATH` resolution for `dart`.
String? get dartExecutable {
  if (Zone.current[environmentOverridesKey] != null) {
    return _resolveDartExecutable();
  }
  if (!_dartExecutableResolved) {
    _cachedDartExecutable = _resolveDartExecutable();
    _dartExecutableResolved = true;
  }
  return _cachedDartExecutable;
}

String? _cachedDartExecutable;
bool _dartExecutableResolved = false;

/// Returns the path to the current Dart SDK.
@Deprecated("Use 'sdkPath' instead")
String? getSdkPath() => sdkPath;

/// Checks whether [candidatePath] represents a valid Dart SDK directory layout.
///
/// Validates that [candidatePath] contains the required file markers of a Dart
/// SDK:
/// - A libraries configuration (`lib/libraries.json` or
///   `lib/_internal/allowed_experiments.json`), AND
/// - An executable or version file (`bin/dart` / `bin/dart.exe` or `version`).
///
/// Returns `false` if [candidatePath] is empty. Relative paths (such as `.` or
/// subdirectories) are evaluated relative to the current working directory.
bool isValidSdkPath(String candidatePath) {
  if (candidatePath.isEmpty) return false;
  final hasLibrariesJson =
      File(path.join(candidatePath, 'lib', 'libraries.json')).existsSync();
  final hasAllowedExperiments =
      File(
        path.join(
          candidatePath,
          'lib',
          '_internal',
          'allowed_experiments.json',
        ),
      ).existsSync();
  final hasDartBin =
      File(
        path.join(
          candidatePath,
          'bin',
          Platform.isWindows ? 'dart.exe' : 'dart',
        ),
      ).existsSync();
  final hasVersion = File(path.join(candidatePath, 'version')).existsSync();

  return (hasLibrariesJson || hasAllowedExperiments) &&
      (hasDartBin || hasVersion);
}

String? _resolveSdkPath() {
  // Tier 1: DART_ROOT and DART_SDK environment variables (explicit overrides)
  final dartRoot = _env['DART_ROOT'];
  if (dartRoot != null && dartRoot.isNotEmpty && isValidSdkPath(dartRoot)) {
    return path.absolute(dartRoot);
  }

  final dartSdk = _env['DART_SDK'];
  if (dartSdk != null && dartSdk.isNotEmpty && isValidSdkPath(dartSdk)) {
    return path.absolute(dartSdk);
  }

  // Tier 2: Platform.resolvedExecutable (Fast path for JIT VM)
  final executablePath =
      _env['_DART_RESOLVED_EXECUTABLE'] ?? Platform.resolvedExecutable;
  if (executablePath.isNotEmpty) {
    final candidate = path.dirname(path.dirname(executablePath));
    if (isValidSdkPath(candidate)) {
      return path.absolute(candidate);
    }
  }

  // Tier 3: PATH traversal with Flutter cache awareness
  for (final candidateExe in _getExecutablePaths('dart')) {
    final file = File(candidateExe);
    if (file.existsSync()) {
      String resolved;
      try {
        resolved = file.resolveSymbolicLinksSync();
      } on FileSystemException {
        resolved = candidateExe;
      }

      // Direct SDK root check
      final candidateSdk = path.dirname(path.dirname(resolved));
      if (isValidSdkPath(candidateSdk)) {
        return path.absolute(candidateSdk);
      }

      // Flutter wrapper check (e.g. flutter/bin/dart -> flutter/bin/cache/dart-sdk)
      final flutterCacheSdk = path.join(
        candidateSdk,
        'bin',
        'cache',
        'dart-sdk',
      );
      if (isValidSdkPath(flutterCacheSdk)) {
        return path.absolute(flutterCacheSdk);
      }
    }
  }

  // Tier 4: FLUTTER_ROOT fallback
  final flutterRoot = _env['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final flutterSdk = path.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
    if (isValidSdkPath(flutterSdk)) {
      return path.absolute(flutterSdk);
    }
  }

  return null;
}

String? _resolveDartExecutable() {
  final sdk = sdkPath;
  if (sdk != null) {
    final exe = path.join(sdk, 'bin', Platform.isWindows ? 'dart.exe' : 'dart');
    if (File(exe).existsSync()) {
      return path.absolute(exe);
    }
  }

  // Fallback: search PATH directly if SDK structure wasn't complete
  for (final candidate in _getExecutablePaths('dart')) {
    if (File(candidate).existsSync()) {
      return path.absolute(candidate);
    }
  }

  return null;
}

Iterable<String> _getExecutablePaths(String executableName) sync* {
  final pathEnv = _env['PATH'];
  if (pathEnv == null || pathEnv.isEmpty) return;

  final separator = Platform.isWindows ? ';' : ':';
  final entries = pathEnv.split(separator);

  final extensions =
      Platform.isWindows
          ? (_env['PATHEXT']?.split(';').where((e) => e.isNotEmpty).toList() ??
              const ['.exe', '.bat', '.cmd', ''])
          : const [''];

  for (final entry in entries) {
    if (entry.isEmpty) continue;
    var cleanEntry = entry.trim();
    if (cleanEntry.startsWith('"') &&
        cleanEntry.endsWith('"') &&
        cleanEntry.length >= 2) {
      cleanEntry = cleanEntry.substring(1, cleanEntry.length - 1);
    }
    if (cleanEntry.isEmpty) continue;
    for (final ext in extensions) {
      yield path.join(cleanEntry, '$executableName$ext');
    }
  }
}

/// The user-specific application configuration folder for the current platform.
///
/// This is a location appropriate for storing application specific
/// configuration for the current user. The [productName] should be unique to
/// avoid clashes with other applications on the same machine. This method won't
/// actually create the folder, merely return the recommended location for
/// storing user-specific application configuration.
///
/// The folder location depends on the platform:
///  * `%APPDATA%\<productName>` on **Windows**,
///  * `$HOME/Library/Application Support/<productName>` on **Mac OS**,
///  * `$XDG_CONFIG_HOME/<productName>` on **Linux**
///     (if `$XDG_CONFIG_HOME` is defined), and,
///  * `$HOME/.config/<productName>` otherwise.
///
/// The chosen location aims to follow best practices for each platform,
/// honoring the [XDG Base Directory Specification][1] on Linux and
/// [File System Basics][2] on Mac OS.
///
/// Throws an [EnvironmentNotFoundException] if an environment entry,
/// `%APPDATA%` or `$HOME`, is needed and not available.
///
/// [1]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
/// [2]: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html#//apple_ref/doc/uid/TP40010672-CH2-SW1
@Deprecated('Use BaseDirectories(productName).configHome instead.')
String applicationConfigHome(String productName) =>
    path.join(_configHome, productName);

String get _configHome {
  if (Platform.isWindows) {
    return _requireEnv('APPDATA');
  }

  if (Platform.isMacOS) {
    return path.join(_requireEnv('HOME'), 'Library', 'Application Support');
  }

  if (Platform.isLinux) {
    final xdgConfigHome = _env['XDG_CONFIG_HOME'];
    if (xdgConfigHome != null) {
      return xdgConfigHome;
    }
    // XDG Base Directory Specification says to use $HOME/.config/ when
    // $XDG_CONFIG_HOME isn't defined.
    return path.join(_requireEnv('HOME'), '.config');
  }

  // We have no guidelines, perhaps we should just do: $HOME/.config/
  // same as XDG specification would specify as fallback.
  return path.join(_requireEnv('HOME'), '.config');
}

String _requireEnv(String name) =>
    _env[name] ?? (throw EnvironmentNotFoundException(name));

/// Exception thrown if a required environment entry does not exist.
///
/// Thrown if an expected and required platform specific environment entry is
/// not available.
class EnvironmentNotFoundException implements Exception {
  /// Name of environment entry which was needed, but not found.
  final String entryName;
  String get message => 'Environment variable \'$entryName\' is not defined!';
  EnvironmentNotFoundException(this.entryName);
  @override
  String toString() => message;
}

/// Zone value key used for testing environment overrides.
@visibleForTesting
const environmentOverridesKey = #_environmentOverrides;

// This zone override exists solely for testing (see lib/cli_util_test.dart).
Map<String, String> get _env =>
    (Zone.current[environmentOverridesKey] as Map<String, String>?) ??
    Platform.environment;
