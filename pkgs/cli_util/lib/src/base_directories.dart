// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:path/path.dart' as path;

import '../cli_util.dart';

/// The standard system paths for a Dart tool.
///
/// These paths respects the following directory standards:
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
  /// The name is used to provide a subdirectory inside the base directories.
  ///
  /// This should be a valid directory name on every operating system. The name
  /// is typically a camel-cased. For example: `"MyApp"`.
  final String tool;

  /// The environment variables to use to determine the base directories.
  ///
  /// Defaults to [Platform.environment].
  final Map<String, String> _environment;

  /// Constructs a [BaseDirectories] instance for the given [tool] name.
  ///
  /// The [environment] map, if provided, is used to determine the base
  /// directories. If omitted, it defaults to using [Platform.environment].
  BaseDirectories(
    this.tool, {
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  /// Path of the directory where the tool will place its caches.
  ///
  /// The cache may be purged by the operating system or use at any time.
  /// Applications should be able to reconstruct any data stored here. If [tool]
  /// cannot handle data being purged, use [runtimeHome] or [dataHome] instead.
  ///
  /// This is a location appropriate for storing non-essential files that may be
  /// removed at any point. For example: intermediate compilation artifacts.
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
  /// Throws an [EnvironmentNotFoundException] if a necessary environment
  /// variable is undefined.
  String cacheHome() => _cacheHome;

  late final _cacheHome =
      path.join(_baseDirectory(_XdgBaseDirectoryKind.cache), tool);

  /// Path of the directory where the tool will place its configuration.
  ///
  /// The configuration may be synchronized across devices by the OS and may
  /// survive application removal.
  ///
  /// This is a location appropriate for storing application specific
  /// configuration for the current user.
  ///
  /// If [plistFiles] is set to `true` on a MacOS platform, the MacOS-specific
  /// configuration directory, which must only contain `.plist` files, is
  /// returned, otherwise a directory that allows non-`.plist` files is
  /// returned. It's the tool's responsibility to only write `.plist` files when
  /// those are required.
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
  /// Throws an [EnvironmentNotFoundException] if a necessary environment
  /// variable is undefined.
  String configHome({bool plistFiles = false}) {
    if (Platform.isMacOS && !plistFiles) {
      return dataHome();
    }
    return _configHome;
  }

  late final _configHome =
      path.join(_baseDirectory(_XdgBaseDirectoryKind.config), tool);

  /// Path of the directory where the tool will place its user data.
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
  /// Throws an [EnvironmentNotFoundException] if a necessary environment
  /// variable is undefined.
  String dataHome() => _dataHome;

  late final _dataHome =
      path.join(_baseDirectory(_XdgBaseDirectoryKind.data), tool);

  /// Path of the directory where the tool will place its runtime data.
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
  /// Throws an [EnvironmentNotFoundException] if a necessary environment
  /// variable is undefined.
  String runtimeHome() => _runtimeHome;

  late final _runtimeHome =
      path.join(_baseDirectory(_XdgBaseDirectoryKind.runtime), tool);

  /// Path of the directory where the tool will place its state.
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
  /// Throws an [EnvironmentNotFoundException] if a necessary environment
  /// variable is undefined.
  String stateHome() => _stateHome;

  late final _stateHome =
      path.join(_baseDirectory(_XdgBaseDirectoryKind.state), tool);

  String _baseDirectory(_XdgBaseDirectoryKind directoryKind) {
    if (Platform.isWindows) {
      return _baseDirectoryWindows(directoryKind);
    }
    if (Platform.isMacOS) {
      return _baseDirectoryMacOs(directoryKind);
    }
    if (Platform.isLinux) {
      return _baseDirectoryLinux(directoryKind);
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  String _baseDirectoryWindows(_XdgBaseDirectoryKind dir) => switch (dir) {
        _XdgBaseDirectoryKind.config ||
        _XdgBaseDirectoryKind.data =>
          _requireEnv('APPDATA'),
        _XdgBaseDirectoryKind.cache ||
        _XdgBaseDirectoryKind.runtime ||
        _XdgBaseDirectoryKind.state =>
          _requireEnv('LOCALAPPDATA'),
      };

  String _baseDirectoryMacOs(_XdgBaseDirectoryKind dir) => switch (dir) {
        _XdgBaseDirectoryKind.config =>
          path.join(_home, 'Library', 'Preferences'),
        _XdgBaseDirectoryKind.data ||
        _XdgBaseDirectoryKind.state =>
          path.join(_home, 'Library', 'Application Support'),
        _XdgBaseDirectoryKind.cache => path.join(_home, 'Library', 'Caches'),
        _XdgBaseDirectoryKind.runtime =>
          // https://stackoverflow.com/a/76799489
          path.join(_home, 'Library', 'Caches', 'TemporaryItems'),
      };

  String _baseDirectoryLinux(_XdgBaseDirectoryKind dir) {
    if (Platform.isLinux) {
      final xdgEnv = switch (dir) {
        _XdgBaseDirectoryKind.config => 'XDG_CONFIG_HOME',
        _XdgBaseDirectoryKind.data => 'XDG_DATA_HOME',
        _XdgBaseDirectoryKind.state => 'XDG_STATE_HOME',
        _XdgBaseDirectoryKind.cache => 'XDG_CACHE_HOME',
        // Note, DIR instead of HOME.
        _XdgBaseDirectoryKind.runtime => 'XDG_RUNTIME_DIR',
      };
      final envVar = _environment[xdgEnv];
      if (envVar != null) {
        return envVar;
      }
    }

    switch (dir) {
      case _XdgBaseDirectoryKind.runtime:
      // Applications should print a fallback message ideally.
      case _XdgBaseDirectoryKind.cache:
        return path.join(_home, '.cache');
      case _XdgBaseDirectoryKind.config:
        return path.join(_home, '.config');
      case _XdgBaseDirectoryKind.data:
        return path.join(_home, '.local', 'share');
      case _XdgBaseDirectoryKind.state:
        return path.join(_home, '.local', 'state');
    }
  }

  String get _home => _requireEnv('HOME');

  String _requireEnv(String name) =>
      _environment[name] ?? (throw EnvironmentNotFoundException(name));
}

/// A kind from the XDG base directory specification for Linux.
///
/// MacOS and Windows have less kinds.
enum _XdgBaseDirectoryKind {
  cache,
  config,
  data,
  // Executables are also mentioned in the XDG spec, but these do not have as
  // well defined of locations on Windows and MacOS.
  runtime,
  state,
}
