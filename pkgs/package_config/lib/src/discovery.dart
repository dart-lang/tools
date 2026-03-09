// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'errors.dart';
import 'package_config.dart';
import 'package_config_io.dart';
import 'package_config_json.dart';
import 'util_io.dart' show defaultLoader, pathJoin;

/// URI used as argument to [Uri.resolveUri] to create package config path.
final Uri _packageConfigJsonPath = Uri(path: '.dart_tool/package_config.json');

/// URI used as argument to [Uri.resolveUri] to convert a URI to a directory.
final Uri _currentPath = Uri(path: '.');

/// URI used as argument to [Uri.resolveUri] to get URI for parent directory.
final Uri _parentPath = Uri(path: '..');

/// Discover the package configuration for a Dart script.
///
/// The [baseDirectory] points to the directory of the Dart script.
/// A package resolution strategy is found by going through the following steps,
/// and stopping when something is found.
///
/// * Check if a `.dart_tool/package_config.json` file exists in the directory.
/// * Repeat this check for the parent directories until reaching the
///   root directory if [recursive] is true.
///
/// If any such a test succeeds, a `PackageConfig` class is returned.
/// Returns `null` if no configuration was found. If a configuration
/// is needed, then the caller can supply [PackageConfig.empty].
///
/// If [minVersion] is greater than the version read from the
/// `package_config.json` file, it too is ignored.
Future<({PackageConfig config, File file})?> findPackageConfig(
  Directory baseDirectory,
  int minVersion,
  bool recursive,
  void Function(Object error) onError,
) async {
  var directory = baseDirectory;
  if (!directory.isAbsolute) directory = directory.absolute;
  if (!await directory.exists()) {
    return null;
  }
  do {
    var packageConfigAndFile = await findPackageConfigInDirectory(
      directory,
      minVersion,
      onError,
    );
    if (packageConfigAndFile != null) return packageConfigAndFile;
    if (!recursive) break;
    // Check in parent directories.
    var parentDirectory = directory.parent;
    if (parentDirectory.path == directory.path) break;
    directory = parentDirectory;
  } while (true);
  return null;
}

/// Similar to [findPackageConfig] but based on a URI.
Future<({PackageConfig config, Uri file})?> findPackageConfigUri(
  Uri location,
  int minVersion,
  Future<Uint8List?> Function(Uri uri)? loader,
  void Function(Object error) onError,
  bool recursive,
) async {
  if (location.isScheme('package')) {
    onError(
      PackageConfigArgumentError(
        location,
        'location',
        'Must not be a package: URI',
      ),
    );
    return null;
  }
  if (loader == null) {
    if (location.isScheme('file')) {
      var configAndFile = await findPackageConfig(
        Directory.fromUri(location.resolveUri(_currentPath)),
        minVersion,
        recursive,
        onError,
      );
      if (configAndFile case (:var config, :var file)) {
        return (config: config, file: file.uri);
      }
    }
    loader = defaultLoader;
  }
  if (!location.path.endsWith('/')) {
    location = location.resolveUri(_currentPath);
  }
  while (true) {
    var file = location.resolveUri(_packageConfigJsonPath);
    var bytes = await loader(file);
    if (bytes != null) {
      var config = parsePackageConfigBytes(bytes, file, onError);
      if (config.version >= minVersion) return (config: config, file: file);
    }
    if (!recursive) break;
    var parent = location.resolveUri(_parentPath);
    if (parent == location) break;
    location = parent;
  }
  return null;
}

/// Finds a `.dart_tool/package_config.json` file in [directory].
///
/// Loads the file, if it is there, and returns the resulting [PackageConfig].
/// Returns `null` if the file isn't there.
/// Reports a [FormatException] if a file is there but the content is not valid.
/// If the file exists, but fails to be read, the file system error is reported.
///
/// If [onError] is supplied, parsing errors are reported using that, and
/// a best-effort attempt is made to return a package configuration.
/// This may be the empty package configuration.
///
/// If [minVersion] is greater than the version read from the
/// `package_config.json` file, it too is ignored.
Future<({PackageConfig config, File file})?> findPackageConfigInDirectory(
  Directory directory,
  int minVersion,
  void Function(Object error) onError,
) async {
  var packageConfigFile = await checkForPackageConfigJsonFile(directory);
  if (packageConfigFile != null) {
    var config = await readConfigFile(packageConfigFile, onError);
    if (config.version < minVersion) return null;
    return (config: config, file: packageConfigFile);
  }
  return null;
}

Future<File?> checkForPackageConfigJsonFile(Directory directory) async {
  assert(directory.isAbsolute);
  var file = File(
    pathJoin(directory.path, '.dart_tool', 'package_config.json'),
  );
  if (await file.exists()) return file;
  return null;
}
