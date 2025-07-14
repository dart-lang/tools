// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:path/path.dart' as path;

import '../cli_util.dart';

/// The standard system paths for a Dart [tool].
///
/// This class respects the following directory standards:
///
/// - On Linux, the [XDG Base Directory
///   Specification](https://specifications.freedesktop.org/basedir-spec/latest/).
/// - On MacOS, the
///   [Library](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)
///   directory.
/// - On Windows, `%APPDATA%` and `%LOCALAPPDATA%`.
///
/// Note that [cacheHome], [configHome], [dataHome], [runtimeHome], and
/// [stateHome] may be overlapping or nested.
///
/// Note that the directories won't be created, the methods merely return the
/// recommended locations.
final class BaseDirectories {
  /// The name of the Dart tool.
  ///
  /// This should be a valid directory name on every operating system,
  /// typically containing only lower-case characters and underscores to ensure
  /// maximum compatibility and readability. For example, "my_dart_tool".
  final String tool;

  /// The environment variables to use.
  ///
  /// Defaults to [Platform.environment].
  final Map<String, String> environment;

  /// Constructs a [BaseDirectories] instance for the given [tool] name.
  BaseDirectories({
    required this.tool,
    Map<String, String>? environment,
  }) : environment = environment ?? Platform.environment;

  /// The path of the directory where [tool] can place its caches.
  ///
  /// The cache might at any point be purged by the operating system or user.
  /// Applications should be able to reconstruct any data stored here. If [tool]
  /// cannot handle data being purged, use [runtimeHome] or [dataHome] instead.
  ///
  /// This is a location appropriate for storing non-essential files that may be
  /// removed at any point.
  ///
  /// The directory location depends on the current [Platform.operatingSystem]:
  /// - on **Windows**:
  ///   - `%LOCALAPPDATA%\<tool>`
  /// - on **Mac OS**:
  ///   - `$HOME/Library/Caches/<tool>`
  /// - on **Linux**:
  ///   - `$XDG_CACHE_HOME/<tool>` if `$XDG_CACHE_HOME` is defined, and
  ///   - `$HOME/.cache/<tool>` otherwise.
  ///
  /// The directory won't be created, the method merely returns the recommended
  /// location.
  ///
  /// On some platforms, this path may overlap with [runtimeHome] and
  /// [stateHome].
  ///
  /// Throws an [EnvironmentNotFoundException] if the necessary environment
  /// variables are undefined.
  String cacheHome() =>
      path.join(_baseDirectory(_XdgBaseDirectoryType.cache), tool);

  /// The path of the directory where [tool] can place its configuration.
  ///
  /// The configuration may be synchronized across devices by the OS and may
  /// survive application removal.
  ///
  /// This is a location appropriate for storing application specific
  /// configuration for the current user.
  ///
  /// The directory location depends on the current [Platform.operatingSystem]
  /// and what file types are stored:
  /// - on **Windows**:
  ///   - `%APPDATA%\<tool>`
  /// - on **Mac OS**:
  ///   - `$HOME/Library/Preferences/<tool>` (may only contain `.plist` files)
  ///     if [plistFiles] is true, and
  ///   - `$HOME/Library/Application Support/<tool>` otherwise.
  /// - on **Linux**:
  ///   - `$XDG_CONFIG_HOME/<tool>` if `$XDG_CONFIG_HOME` is defined, and
  ///   - `$HOME/.config/<tool>` otherwise.
  ///
  /// The directory won't be created, the method merely returns the recommended
  /// location.
  ///
  /// On some platforms, this path may overlap with [dataHome].
  ///
  /// Throws an [EnvironmentNotFoundException] if the necessary environment
  /// variables are undefined.
  String configHome({bool plistFiles = false}) {
    if (Platform.isMacOS && !plistFiles) {
      return dataHome();
    }
    return path.join(_baseDirectory(_XdgBaseDirectoryType.config), tool);
  }

  /// The path of the directory where [tool] can place its user data.
  ///
  /// The data may be backed up and synchronized to other devices by the
  /// operating system. For large data use [stateHome] instead.
  ///
  /// This is a location appropriate for storing application specific
  /// data for the current user. For example: documents created by the user.
  ///
  /// The directory location depends on the current [Platform.operatingSystem]:
  /// - on **Windows**:
  ///   - `%APPDATA%\<tool>`
  /// - on **Mac OS**:
  ///   - `$HOME/Library/Application Support/<tool>`
  /// - on **Linux**:
  ///   - `$XDG_DATA_HOME/<tool>` if `$XDG_DATA_HOME` is defined, and
  ///   - `$HOME/.local/share/<tool>` otherwise.
  ///
  /// The directory won't be created, the method merely returns the recommended
  /// location.
  ///
  /// On some platforms, this path may overlap with [configHome] and
  /// [stateHome].
  ///
  /// Throws an [EnvironmentNotFoundException] if the necessary environment
  /// variables are undefined.
  String dataHome() =>
      path.join(_baseDirectory(_XdgBaseDirectoryType.data), tool);

  /// The path of the directory where [tool] can place its runtime data.
  ///
  /// The runtime data may be deleted in between user logins by the OS. For data
  /// that needs to persist between sessions, use [stateHome] instead.
  ///
  /// This is a location appropriate for storing runtime data for the current
  /// session. For example: undo history.
  ///
  /// The directory location depends on the current [Platform.operatingSystem]:
  /// - on **Windows**:
  ///   - `%LOCALAPPDATA%\<tool>`
  /// - on **Mac OS**:
  ///   - `$HOME/Library/Caches/TemporaryItems/<tool>`
  /// - on **Linux**:
  ///   - `$XDG_RUNTIME_HOME/<tool>` if `$XDG_RUNTIME_HOME` is defined, and
  ///   - `$HOME/.cache/<tool>` otherwise.
  ///
  /// The directory won't be created, the method merely returns the recommended
  /// location.
  ///
  /// On some platforms, this path may overlap [cacheHome] and [stateHome] or be
  /// nested in [cacheHome].
  ///
  /// Throws an [EnvironmentNotFoundException] if the necessary environment
  /// variables are undefined.
  String runtimeHome() =>
      path.join(_baseDirectory(_XdgBaseDirectoryType.runtime), tool);

  /// The path of the directory where [tool] can place its state.
  ///
  /// The state directory is likely not backed up or synchronized accross
  /// devices by the OS. For data that may be backed up and synchronized, use
  /// [dataHome] instead.
  ///
  /// This is a location appropriate for storing data which is either not
  /// important enougn, not small enough, or not portable enough to store in
  /// [dataHome]. For example: logs and indices.
  ///
  /// The directory location depends on the current [Platform.operatingSystem]:
  /// - on **Windows**:
  ///   - `%LOCALAPPDATA%\<tool>`
  /// - on **Mac OS**:
  ///   - `$HOME/Library/Application Support/<tool>`
  /// - on **Linux**:
  ///   - `$XDG_STATE_HOME/<tool>` if `$XDG_STATE_HOME` is defined, and
  ///   - `$HOME/.local/state/<tool>` otherwise.
  ///
  /// The directory won't be created, the method merely returns the recommended
  /// location.
  ///
  /// On some platforms, this path may overlap with [cacheHome], and
  /// [runtimeHome].
  ///
  /// Throws an [EnvironmentNotFoundException] if the necessary environment
  /// variables are undefined.
  String stateHome() =>
      path.join(_baseDirectory(_XdgBaseDirectoryType.state), tool);

  String _baseDirectory(_XdgBaseDirectoryType dir) {
    if (Platform.isWindows) {
      return _baseDirectoryWindows(dir);
    }
    if (Platform.isMacOS) {
      return _baseDirectoryMacOs(dir);
    }
    if (Platform.isLinux) {
      return _baseDirectoryLinux(dir);
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  String _baseDirectoryWindows(_XdgBaseDirectoryType dir) => switch (dir) {
        _XdgBaseDirectoryType.config ||
        _XdgBaseDirectoryType.data =>
          _requireEnv('APPDATA'),
        _XdgBaseDirectoryType.cache ||
        _XdgBaseDirectoryType.runtime ||
        _XdgBaseDirectoryType.state =>
          _requireEnv('LOCALAPPDATA'),
      };

  String _baseDirectoryMacOs(_XdgBaseDirectoryType dir) => switch (dir) {
        _XdgBaseDirectoryType.config =>
          path.join(_home, 'Library', 'Preferences'),
        _XdgBaseDirectoryType.data ||
        _XdgBaseDirectoryType.state =>
          path.join(_home, 'Library', 'Application Support'),
        _XdgBaseDirectoryType.cache => path.join(_home, 'Library', 'Caches'),
        _XdgBaseDirectoryType.runtime =>
          // https://stackoverflow.com/a/76799489
          path.join(_home, 'Library', 'Caches', 'TemporaryItems'),
      };

  String _baseDirectoryLinux(_XdgBaseDirectoryType dir) {
    if (Platform.isLinux) {
      final xdgEnv = switch (dir) {
        _XdgBaseDirectoryType.config => 'XDG_CONFIG_HOME',
        _XdgBaseDirectoryType.data => 'XDG_DATA_HOME',
        _XdgBaseDirectoryType.state => 'XDG_STATE_HOME',
        _XdgBaseDirectoryType.cache => 'XDG_CACHE_HOME',
        // Note, DIR instead of HOME.
        _XdgBaseDirectoryType.runtime => 'XDG_RUNTIME_DIR',
      };
      final envVar = environment[xdgEnv];
      if (envVar != null) {
        return envVar;
      }
    }

    switch (dir) {
      case _XdgBaseDirectoryType.runtime:
      // Applications should print a fallback message ideally.
      case _XdgBaseDirectoryType.cache:
        return path.join(_home, '.cache');
      case _XdgBaseDirectoryType.config:
        return path.join(_home, '.config');
      case _XdgBaseDirectoryType.data:
        return path.join(_home, '.local', 'share');
      case _XdgBaseDirectoryType.state:
        return path.join(_home, '.local', 'state');
    }
  }

  String get _home => _requireEnv('HOME');

  String _requireEnv(String name) =>
      environment[name] ?? (throw EnvironmentNotFoundException(name));
}

enum _XdgBaseDirectoryType {
  cache,
  config,
  data,
  // Executables are also mentioned in the XDG spec, but these do not have as
  // well defined of locations on Windows and MacOS.
  runtime,
  state,
}
