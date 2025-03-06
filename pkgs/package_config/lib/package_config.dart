// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A package configuration is a way to assign file paths to package URIs,
/// and vice-versa.
///
/// This package provides functionality to find, read and write package
/// configurations in the [specified format](https://github.com/dart-lang/language/blob/master/accepted/future-releases/language-versioning/package-config-file-v2.md).
library;

import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'src/discovery.dart' as discover;
import 'src/errors.dart' show throwError;
import 'src/package_config.dart';
import 'src/package_config_io.dart';

export 'package_config_types.dart';

/// Reads a specific package configuration file.
///
/// The file must exist, be readable and be a valid `package_config.json` file.
///
/// If [onError] is provided, the configuration file parsing will report errors
/// by calling that function, and then try to recover.
/// The returned package configuration is a *best effort* attempt to create
/// a valid configuration from the invalid configuration file.
/// If no [onError] is provided, errors are thrown immediately.
Future<PackageConfig> loadPackageConfig(File file,
        {void Function(Object error)? onError}) =>
    readConfigFile(file, onError ?? throwError);

/// @nodoc
@Deprecated('use loadPackageConfig instead')
Future<PackageConfig> loadAnyPackageConfig(File file,
        {bool preferNewest = true, void Function(Object error)? onError}) =>
    loadPackageConfig(file, onError: onError);

/// Reads a specific package configuration URI.
///
/// The file of the URI must exist, be readable,
/// and be  a valid `package_config.json` file.
///
/// If [loader] is provided, URIs are loaded using that function.
/// The future returned by the loader must complete with a [Uint8List]
/// containing the entire file content encoded as UTF-8,
/// or with `null` if the file does not exist.
/// The loader may throw at its own discretion, for situations where
/// it determines that an error might be need user attention,
/// but it is always allowed to return `null`.
/// This function makes no attempt to catch such errors.
/// As such, it may throw any error that [loader] throws.
///
/// If no [loader] is supplied, a default loader is used which
/// only accepts `file:`,  `http:` and `https:` URIs,
/// and which uses the platform file system and HTTP requests to
/// fetch file content. The default loader never throws because
/// of an I/O issue, as long as the location URIs are valid.
/// As such, it does not distinguish between a file not existing,
/// and it being temporarily locked or unreachable.
///
/// If [onError] is provided, the configuration file parsing will report errors
/// by calling that function, and then try to recover.
/// The returned package configuration is a *best effort* attempt to create
/// a valid configuration from the invalid configuration file.
/// If no [onError] is provided, errors are thrown immediately.
Future<PackageConfig> loadPackageConfigUri(Uri file,
        {Future<Uint8List?> Function(Uri uri)? loader,
        void Function(Object error)? onError}) =>
    readConfigFileUri(file, loader, onError ?? throwError);

/// @nodoc
@Deprecated('use loadPackageConfigUri instead')
Future<PackageConfig> loadAnyPackageConfigUri(Uri uri,
        {bool preferNewest = true, void Function(Object error)? onError}) =>
    loadPackageConfigUri(uri, onError: onError);

/// Finds a package configuration relative to [directory].
///
/// If [directory] contains a `.dart_tool/package_config.json` file,
/// then that file is loaded.
///
/// If no file is found in the current directory,
/// then the parent directories are checked recursively,
/// all the way to the root directory, to check if those contains
/// a package configuration.
/// If [recurse] is set to `false`, this parent directory check is not
/// performed.
///
/// If [onError] is provided, the configuration file parsing will report errors
/// by calling that function, and then try to recover.
/// The returned package configuration is a *best effort* attempt to create
/// a valid configuration from the invalid configuration file.
/// If no [onError] is provided, errors are thrown immediately.
///
/// If [minVersion] is set to something greater than its default,
/// any lower-version configuration files are ignored in the search.
///
/// Returns `null` if no configuration file is found.
Future<PackageConfig?> findPackageConfig(Directory directory,
    {bool recurse = true,
    void Function(Object error)? onError,
    int minVersion = 1}) {
  if (minVersion > PackageConfig.maxVersion) {
    throw ArgumentError.value(minVersion, 'minVersion',
        'Maximum known version is ${PackageConfig.maxVersion}');
  }
  return discover.findPackageConfig(
      directory, minVersion, recurse, onError ?? throwError);
}

/// Finds a package configuration relative to [location].
///
/// If [location] contains a `.dart_tool/package_config.json`
/// package configuration file or, then that file is loaded.
/// The [location] URI *must not* be a `package:` URI.
/// It should be a hierarchical URI which is supported
/// by [loader].
///
/// If no file is found in the current directory,
/// then the parent directories are checked recursively,
/// all the way to the root directory, to check if those contains
/// a package configuration.
/// If [recurse] is set to `false`, this parent directory check is not
/// performed.
///
/// If [loader] is provided, URIs are loaded using that function.
/// The future returned by the loader must complete with a [Uint8List]
/// containing the entire file content,
/// or with `null` if the file does not exist.
/// The loader may throw at its own discretion, for situations where
/// it determines that an error might be need user attention,
/// but it is always allowed to return `null`.
/// This function makes no attempt to catch such errors.
///
/// If no [loader] is supplied, a default loader is used which
/// only accepts `file:`,  `http:` and `https:` URIs,
/// and which uses the platform file system and HTTP requests to
/// fetch file content. The default loader never throws because
/// of an I/O issue, as long as the location URIs are valid.
/// As such, it does not distinguish between a file not existing,
/// and it being temporarily locked or unreachable.
///
/// If [onError] is provided, the configuration file parsing will report errors
/// by calling that function, and then try to recover.
/// The returned package configuration is a *best effort* attempt to create
/// a valid configuration from the invalid configuration file.
/// If no [onError] is provided, errors are thrown immediately.
///
/// If [minVersion] is set to something greater than its default,
/// any lower-version configuration files are ignored in the search.
///
/// Returns `null` if no configuration file is found.
Future<PackageConfig?> findPackageConfigUri(Uri location,
    {bool recurse = true,
    int minVersion = 1,
    Future<Uint8List?> Function(Uri uri)? loader,
    void Function(Object error)? onError}) {
  if (minVersion > PackageConfig.maxVersion) {
    throw ArgumentError.value(minVersion, 'minVersion',
        'Maximum known version is ${PackageConfig.maxVersion}');
  }
  return discover.findPackageConfigUri(
      location, minVersion, loader, onError ?? throwError, recurse);
}

/// Writes a package configuration to the provided directory.
///
/// Writes `.dart_tool/package_config.json` relative to [directory].
/// If the `.dart_tool/` directory does not exist, it is created.
/// If it cannot be created, this operation fails.
///
/// A comment is generated if `[PackageConfig.extraData]` contains a
/// `"generator"` entry.
Future<void> savePackageConfig(
        PackageConfig configuration, Directory directory) =>
    writePackageConfigJsonFile(configuration, directory);
