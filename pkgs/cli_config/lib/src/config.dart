// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'cli_parser.dart';
import 'cli_source.dart';
import 'environment_parser.dart';
import 'environment_source.dart';
import 'file_parser.dart';
import 'file_source.dart';
import 'source.dart';

/// A hierarchical configuration.
/// Configuration can be provided from three sources: commandline arguments,
/// environment variables and configuration files. This configuration makes
/// these accessible via a uniform API.
///
/// Configuration can be provided via the three sources as follows:
/// 1. commandline argument defines as `-Dsome_key=some_value`,
/// 2. environment variables as `SOME_KEY=some_value`, and
/// 3. config files as JSON or YAML as `{'some_key': 'some_value'}`.
///
/// The default lookup behavior is that commandline argument defines take
/// precedence over environment variables, which take precedence over the
/// configuration file.
///
/// If a single value is requested from this configuration, the first source
/// that can provide the value will provide it. For example
/// `config.getString('some_key')` with `{'some_key': 'file_value'}` in the
/// config file and `-Dsome_key=cli_value` as commandline argument returns
/// `'cli_value'`. The implication is that you can not remove keys from the
/// configuration file, only overwrite or append them.
///
/// If a list value is requested from this configuration, the values provided
/// by the various sources can be combined or not. For example
/// `config.getStringList('some_key', combineAllConfigs: true)` returns
/// `['cli_value', 'file_value']`.
///
/// The config is hierarchical in nature, using `.` as the hierarchy separator
/// for lookup and commandline defines. The hierarchy should be materialized in
/// the JSON or YAML configuration file. For environment variables `__` is used
/// as hierarchy separator.
///
/// Hierarchical configuration can be provided via the three sources as follows:
/// 1. commandline argument defines as `-Dsome_key.some_nested_key=some_value`,
/// 2. environment variables as `SOME_KEY__SOME_NESTED_KEY=some_value`, and
/// 3. config files as JSON or YAML as
///    ```yaml
///    some_key:
///      some_nested_key:
///        some_value
///    ```
///
/// The config is opinionated on the format of the keys in the sources.
/// * Command-line argument keys should be lower-cased alphanumeric
///   characters or underscores, with `.` for hierarchy.
/// * Environment variables keys should be upper-cased alphanumeric
///    characters or underscores, with `__` for hierarchy.
/// * Config files keys should be lower-cased alphanumeric
///   characters or underscores.
///
/// In the API they are made available lower-cased and with underscores, and
/// `.` as hierarchy separator.
class Config {
  final CliSource _cliSource;
  final EnvironmentSource _environmentSource;
  final FileSource _fileSource;

  /// Config sources, ordered by precedence.
  late final _sources = [_cliSource, _environmentSource, _fileSource];

  Config._(
    this._cliSource,
    this._environmentSource,
    this._fileSource,
  );

  /// Constructs a config by parsing the three sources.
  ///
  /// If provided, [commandLineDefines] must be a list of '<key>=<value>'.
  ///
  /// If provided, [environment] must be a map containing environment variables.
  ///
  /// If provided, [fileParsed] must be valid parsed YSON or YAML (maps, lists,
  /// strings, integers, and booleans).
  ///
  /// If provided [fileSourceUri], is used to resolve paths inside
  /// [fileContents] and to provide better error messages on parsing the
  /// configuration file.
  factory Config({
    List<String> commandLineDefines = const [],
    Map<String, String> environment = const {},
    Map<String, dynamic> fileParsed = const {},
    Uri? fileSourceUri,
  }) {
    // Parse config file.
    final fileConfig = FileParser().parseMap(fileParsed);

    // Parse CLI argument defines.
    final cliConfig = DefinesParser().parse(commandLineDefines);

    // Parse environment.
    final environmentConfig = EnvironmentParser().parse(environment);

    return Config._(
      CliSource(cliConfig),
      EnvironmentSource(environmentConfig),
      FileSource(fileConfig, fileSourceUri),
    );
  }

  /// Constructs a config by parsing the three sources.
  ///
  /// If provided, [commandLineDefines] must be a list of '<key>=<value>'.
  ///
  /// If provided, [environment] must be a map containing environment variables.
  ///
  /// If provided, [fileContents] must be valid JSON or YAML.
  ///
  /// If provided [fileSourceUri], is used to resolve paths inside
  /// [fileContents] and to provide better error messages on parsing the
  /// configuration file.
  factory Config.fromConfigFileContents({
    List<String> commandLineDefines = const [],
    Map<String, String> environment = const {},
    String? fileContents,
    Uri? fileSourceUri,
  }) {
    // Parse config file.
    final Map<String, dynamic> fileConfig;
    if (fileContents != null) {
      fileConfig = FileParser().parse(
        fileContents,
        sourceUrl: fileSourceUri,
      );
    } else {
      fileConfig = {};
    }

    // Parse CLI argument defines.
    final cliConfig = DefinesParser().parse(commandLineDefines);

    // Parse environment.
    final environmentConfig = EnvironmentParser().parse(environment);

    return Config._(
      CliSource(cliConfig),
      EnvironmentSource(environmentConfig),
      FileSource(fileConfig, fileSourceUri),
    );
  }

  /// Constructs a config by parsing CLI arguments and loading the config file.
  ///
  /// The [args] must be commandline arguments.
  ///
  /// If provided, [environment] must be a map containing environment variables.
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

    return Config.fromConfigFileContents(
      commandLineDefines: results['define'] as List<String>,
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
    for (final source in _sources) {
      value ??= source.getOptionalString(key);
    }
    if (validValues != null) {
      Source.throwIfUnexpectedValue(key, value, validValues);
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
      _cliSource: splitCliPattern,
      _environmentSource: splitEnvironmentPattern,
      _fileSource: null
    }.entries) {
      final source = entry.key;
      final splitPattern = entry.value;
      final value =
          source.getOptionalStringList(key, splitPattern: splitPattern);
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
    'no': false,
    'NO': false,
    'true': true,
    'TRUE': true,
    'yes': true,
    'YES': true,
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
    for (final source in _sources) {
      value ??= source.getOptionalBool(key);
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
    for (final source in _sources) {
      final path = source.getOptionalString(key);
      if (path != null) {
        final value = _pathToUri(
          path,
          resolveUri: resolveFileUri && source == _fileSource,
          baseUri: source.baseUri,
        );
        if (mustExist) {
          _throwIfNotExists(key, value);
        }
        return value;
      }
    }
    return null;
  }

  Uri _pathToUri(
    String path, {
    required bool resolveUri,
    required Uri? baseUri,
  }) {
    if (resolveUri && baseUri != null) {
      return baseUri.resolve(path);
    }
    return Source.fileSystemPathToUri(path);
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
      _cliSource: splitCliPattern,
      _environmentSource: splitEnvironmentPattern,
      _fileSource: null
    }.entries) {
      final source = entry.key;
      final splitPattern = entry.value;
      final paths = source.getOptionalStringList(
        key,
        splitPattern: splitPattern,
      );
      if (paths != null) {
        final value = [
          for (final path in paths)
            _pathToUri(
              path,
              resolveUri: resolveFileUri && source == _fileSource,
              baseUri: source.baseUri,
            )
        ];
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
  T? getFileValue<T>(String key) => _fileSource.getValue(key);

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
  String toString() => 'Config($_sources)';
}

extension on Uri {
  FileSystemEntity get fileSystemEntity {
    if (path.endsWith(Platform.pathSeparator)) {
      return Directory.fromUri(this);
    }
    return File.fromUri(this);
  }
}
