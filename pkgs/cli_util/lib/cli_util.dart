// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utilities to locate the Dart SDK.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

/// The path to the current Dart SDK.
String get sdkPath => path.dirname(path.dirname(Platform.resolvedExecutable));

/// Returns the path to the current Dart SDK.
@Deprecated("Use 'sdkPath' instead")
String getSdkPath() => sdkPath;

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
/// Thrown by [applicationConfigHome] if an expected and required
/// platform specific environment entry is not available.
class EnvironmentNotFoundException implements Exception {
  /// Name of environment entry which was needed, but not found.
  final String entryName;
  String get message => 'Environment variable \'$entryName\' is not defined!';
  EnvironmentNotFoundException(this.entryName);
  @override
  String toString() => message;
}

// This zone override exists solely for testing (see lib/cli_util_test.dart).
Map<String, String> get _env =>
    (Zone.current[#environmentOverrides] as Map<String, String>?) ??
    Platform.environment;
