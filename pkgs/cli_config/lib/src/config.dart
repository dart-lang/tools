// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'cli_parser.dart';
import 'cli_provider.dart';
import 'environment_parser.dart';
import 'environment_provider.dart';
import 'file_parser.dart';
import 'file_provider.dart';
import 'provider.dart';

/// A hierarchical configuration object.
///
/// Configuration can be provided as commandline arguments, environment
/// variables and configuration files. This configuration object makes
/// these accessible with a uniform API.
///
/// Configuration can be provided in three ways:
/// 1. commandline argument defines as `-Dsome_key=some_value`,
/// 2. environment variables as `SOME_KEY=some_value`, and
/// 3. config files as JSON or YAML as `{'some_key': 'some_value'}`.
///
/// The default lookup behavior is that commandline argument defines take
/// precedence over environment variables, which take precedence over the
/// configuration file.
///
/// The config is hierarchical in nature, using `.` as the hierarchy separator
/// for lookup and commandline defines. The hierarchy should be materialized in
/// the JSON or YAML configuration file. For environment variables `__` is used
/// as hierarchy separator.
///
/// Hierarchical configuration can be provided in three ways:
/// 1. commandline argument defines as `-Dsome_key.some_nested_key=some_value`,
/// 2. environment variables as `SOME_KEY__SOME_NESTED_KEY=some_value`, and
/// 3. config files as JSON or YAML as
///    ```yaml
///    some_key:
///      some_nested_key:
///        some_value
///    ```
///
/// The config is opinionated on the format of the keys.
/// * Command-line argument keys should be lower-cased alphanumeric
///   characters or underscores, with `.` for hierarchy.
/// * Environment variables keys should be upper-cased alphanumeric
///    characters or underscores, with `__` for hierarchy.
/// * Config files keys should be lower-cased alphanumeric
///   characters or underscores.
///
/// In the API they are made available lower-cased and with underscores.
class Config {
  final CliProvider _cliProvider;
  final EnvironmentProvider _environmentProvider;
  final FileProvider _fileProvider;

  /// Config providers, ordered by precedence.
  late final _providers = [_cliProvider, _environmentProvider, _fileProvider];

  Config._(
    this._cliProvider,
    this._environmentProvider,
    this._fileProvider,
  );

  /// Constructs a config by parsing the three sources.
  ///
  /// If provided, [cliDefines] must be a list of '<key>=<value>'.
  ///
  /// If provided, [environment] must be a map containing environment varibales.
  ///
  /// At most one of [fileContents] or [fileParsed] must be provided.
  /// If provided, [fileContents] must be valid JSON or YAML.
  /// If provided, [fileParsed] must be valid parsed YSON or YAML (maps, lists,
  /// strings, integers, and booleans).
  ///
  /// If provided [fileSourceUri], is used to provide better error messages on
  /// parsing the configuration file.
  factory Config({
    List<String> cliDefines = const [],
    Map<String, String> environment = const {},
    Map<String, dynamic>? fileParsed,
    String? fileContents,
    Uri? fileSourceUri,
  }) {
    // Parse config file.
    if (_countNonNulls([fileContents, fileParsed]) > 1) {
      throw ArgumentError(
          'Provide at most one of `fileParsed` and `fileContents`.');
    }
    final Map<String, dynamic> fileConfig;
    if (fileParsed != null) {
      fileConfig = FileParser().parseMap(fileParsed);
    } else if (fileContents != null) {
      fileConfig = FileParser().parse(
        fileContents,
        sourceUrl: fileSourceUri,
      );
    } else {
      fileConfig = {};
    }

    // Parse CLI argument defines.
    final cliConfig = DefinesParser().parse(cliDefines);

    // Parse environment.
    final environmentConfig = EnvironmentParser().parse(environment);

    return Config._(
      CliProvider(cliConfig),
      EnvironmentProvider(environmentConfig),
      FileProvider(fileConfig, fileSourceUri),
    );
  }

  /// Constructs a config by parsing CLI arguments and loading the config file.
  ///
  /// The [args] must be commandline arguments.
  ///
  /// If provided, [environment] must be a map containing environment varibales.
  /// If not provided, [environment] defaults to [Platform.environment].
  ///
  /// This async constructor is intended to be used directly in CLI files.
  static Future<Config> fromArgs({
    required List<String> args,
    Map<String, String>? environment,
  }) async {
    final results = CliParser().parse(args);

    // Load config file.
    final configFile = results['config'] as String?;
    String? fileContents;
    Uri? fileSourceUri;
    if (configFile != null) {
      fileContents = await File(configFile).readAsString();
      fileSourceUri = Uri.file(configFile);
    }

    return Config(
      cliDefines: results['define'] as List<String>,
      environment: environment ?? Platform.environment,
      fileContents: fileContents,
      fileSourceUri: fileSourceUri,
    );
  }

  /// Lookup a string value in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// Throws if one of the configs does not contain the expected value type.
  ///
  /// If [validValues] is provided, throws if an unxpected value is provided.
  String getString(String key, {Iterable<String>? validValues}) {
    final value = getOptionalString(key, validValues: validValues);
    _throwIfNull(key, value);
    return value!;
  }

  /// Lookup a nullable string value in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// If [validValues] is provided, throws if an unxpected value is provided.
  String? getOptionalString(String key, {Iterable<String>? validValues}) {
    String? value;
    for (final provider in _providers) {
      value ??= provider.getOptionalString(key);
    }
    if (validValues != null) {
      Provider.throwIfUnexpectedValue(key, value, validValues);
    }
    return value;
  }

  /// Lookup a nullable string list in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// If [combineAllConfigs] combines results from cli, environment, and
  /// config file. Otherwise, precedence rules apply.
  ///
  /// If provided, [splitCliPattern] splits cli defines.
  /// For example: `-Dfoo=bar;baz` can be split on `;`.
  /// If not provided, a list can still be provided with multiple cli defines.
  /// For example: `-Dfoo=bar -Dfoo=baz`.
  ///
  /// If provided, [splitEnvironmentPattern] splits environment values.
  List<String>? getOptionalStringList(
    String key, {
    bool combineAllConfigs = true,
    String? splitCliPattern,
    String? splitEnvironmentPattern,
  }) {
    List<String>? result;
    for (final entry in {
      _cliProvider: splitCliPattern,
      _environmentProvider: splitEnvironmentPattern,
      _fileProvider: null
    }.entries) {
      final provider = entry.key;
      final splitPattern = entry.value;
      final value =
          provider.getOptionalStringList(key, splitPattern: splitPattern);
      if (value != null) {
        if (combineAllConfigs) {
          (result ??= []).addAll(value);
        } else {
          return value;
        }
      }
    }
    return result;
  }

  static const boolStrings = {
    '0': false,
    '1': true,
    'false': false,
    'FALSE': false,
    'true': true,
    'TRUE': true,
  };

  /// Lookup a boolean value in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// For cli defines and environment variables, the value must be one of
  /// [boolStrings].
  /// For the config file, it must be a boolean.
  ///
  /// Throws if one of the configs does not contain the expected value type.
  bool getBool(String key) {
    final value = getOptionalBool(key);
    _throwIfNull(key, value);
    return value!;
  }

  /// Lookup an optional boolean value in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// For cli defines and environment variables, the value must be one of
  /// [boolStrings].
  /// For the config file, it must be a boolean.
  bool? getOptionalBool(String key) {
    bool? value;
    for (final provider in _providers) {
      value ??= provider.getOptionalBool(key);
    }
    return value;
  }

  /// Lookup a path in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// Throws if one of the configs does not contain the expected value type.
  ///
  /// If [resolveFileUri], resolves the paths in config file relative to the
  /// config file.
  ///
  /// If [mustExist], throws if the path doesn't resolve to a file or directory
  /// on the file system.
  ///
  /// Throws if one of the configs does not contain the expected value type.
  Uri getPath(
    String key, {
    bool resolveFileUri = true,
    bool mustExist = false,
  }) {
    final value = getOptionalPath(key,
        resolveFileUri: resolveFileUri, mustExist: mustExist);
    _throwIfNull(key, value);
    return value!;
  }

  /// Lookup an optional path in this config.
  ///
  /// First tries CLI argument defines, then environment variables, and
  /// finally the config file.
  ///
  /// Throws if one of the configs does not contain the expected value type.
  ///
  /// If [resolveFileUri], resolves the paths in config file relative to the
  /// config file.
  ///
  /// If [mustExist], throws if the path doesn't resolve to a file or directory
  /// on the file system.
  Uri? getOptionalPath(
    String key, {
    bool resolveFileUri = true,
    bool mustExist = false,
  }) {
    Uri? value;
    value ??= _cliProvider.getOptionalPath(key);
    value ??= _environmentProvider.getOptionalPath(key);
    value ??= _fileProvider.getOptionalPath(key, resolveUri: resolveFileUri);
    if (mustExist && value != null) {
      _throwIfNotExists(key, value);
    }
    return value;
  }

  /// Lookup a list of paths in this config.
  ///
  /// If [combineAllConfigs] combines results from cli, environment, and
  /// config file. Otherwise, precedence rules apply.
  ///
  /// If provided, [splitCliPattern] splits cli defines.
  ///
  /// If provided, [splitEnvironmentPattern] splits environment values.
  ///
  /// If [resolveFileUri], resolves the paths in config file relative to the
  /// config file.
  List<Uri>? getOptionalPathList(
    String key, {
    bool combineAllConfigs = true,
    String? splitCliPattern,
    String? splitEnvironmentPattern,
    bool resolveFileUri = true,
  }) {
    List<Uri>? result;
    for (final entry in {
      _cliProvider: splitCliPattern,
      _environmentProvider: splitEnvironmentPattern,
      _fileProvider: null
    }.entries) {
      final provider = entry.key;
      final splitPattern = entry.value;
      final value = provider.getOptionalPathList(
        key,
        splitPattern: splitPattern,
        resolveUri: resolveFileUri && provider == _fileProvider,
      );
      if (value != null) {
        if (combineAllConfigs) {
          (result ??= []).addAll(value);
        } else {
          return value;
        }
      }
    }
    return result;
  }

  /// Lookup a [T] in the config file.
  ///
  /// Only available for the configuration file, cannot be overwritten with
  /// commandline defines or environment variables.
  T? getFileValue<T>(String key) => _fileProvider.getValue(key);

  void _throwIfNull(String key, Object? value) {
    if (value == null) {
      throw FormatException('No value was provided for required key: $key');
    }
  }

  void _throwIfNotExists(String key, Uri value) {
    if (!value.fileSystemEntity.existsSync()) {
      throw FormatException("Path '$value' for key '$key' doesn't exist.");
    }
  }

  @override
  String toString() => 'Config($_providers)';
}

extension on Uri {
  FileSystemEntity get fileSystemEntity {
    if (path.endsWith(Platform.pathSeparator)) {
      return Directory.fromUri(this);
    }
    return File.fromUri(this);
  }
}

int _countNonNulls(List<Object?> objects) => objects.whereType<Object>().length;
