// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:io";
import 'dart:typed_data';

import "package:path/path.dart" as path;

import "errors.dart";
import "package_config_impl.dart";
import "package_config_json.dart";
import "packages_file.dart" as packages_file;
import "util.dart" show defaultLoader;

final Uri packageConfigJsonPath = Uri(path: ".dart_tool/package_config.json");
final Uri dotPackagesPath = Uri(path: ".packages");
final Uri currentPath = Uri(path: ".");
final Uri parentPath = Uri(path: "..");

/// Discover the package configuration for a Dart script.
///
/// The [baseDirectory] points to the directory of the Dart script.
/// A package resolution strategy is found by going through the following steps,
/// and stopping when something is found.
///
/// * Check if a `.dart_tool/package_config.json` file exists in the directory.
/// * Check if a `.packages` file exists in the directory.
/// * Repeat these checks for the parent directories until reaching the
///   root directory if [recursive] is true.
///
/// If any of these tests succeed, a `PackageConfig` class is returned.
/// Returns `null` if no configuration was found. If a configuration
/// is needed, then the caller can supply [PackageConfig.empty].
Future<PackageConfig /*?*/ > findPackageConfig(
    Directory baseDirectory, bool recursive) async {
  var directory = baseDirectory;
  if (!directory.isAbsolute) directory = directory.absolute;
  if (!await directory.exists()) {
    return null;
  }
  do {
    // Check for $cwd/.packages
    var packageConfig = await findPackagConfigInDirectory(directory);
    if (packageConfig != null) return packageConfig;
    if (!recursive) break;
    // Check in parent directories.
    var parentDirectory = directory.parent;
    if (parentDirectory.path == directory.path) break;
    directory = parentDirectory;
  } while (true);
  return null;
}

/// Similar to [findPackageConfig] but based on a URI.
Future<PackageConfig /*?*/ > findPackageConfigUri(Uri location,
    Future<Uint8List /*?*/ > loader(Uri uri) /*?*/, bool recursive) async {
  if (location.isScheme("package")) {
    throw PackageConfigArgumentError(
        location, "location", "Must not be a package: URI");
  }
  if (loader == null) {
    if (location.isScheme("file")) {
      return findPackageConfig(
          Directory.fromUri(location.resolveUri(currentPath)), recursive);
    }
    loader = defaultLoader;
  }
  if (!location.path.endsWith("/")) location = location.resolveUri(currentPath);
  while (true) {
    var file = location.resolveUri(packageConfigJsonPath);
    var bytes = await loader(file);
    if (bytes != null) {
      return parsePackageConfigBytes(bytes, file);
    }
    file = location.resolveUri(dotPackagesPath);
    bytes = await loader(file);
    if (bytes != null) {
      return packages_file.parse(bytes, file);
    }
    if (!recursive) break;
    var parent = location.resolveUri(parentPath);
    if (parent == location) break;
    location = parent;
  }
  return null;
}

/// Finds a `.packages` or `.dart_tool/package_config.json` file in [directory].
///
/// Loads the file, if it is there, and returns the resulting [PackageConfig].
/// Returns `null` if the file isn't there.
/// Throws [FormatException] if a file is there but is not valid.
///
/// If [extraData] is supplied and the `package_config.json` contains extra
/// entries in the top JSON object, those extra entries are stored into
/// [extraData].
Future<PackageConfig /*?*/ > findPackagConfigInDirectory(
    Directory directory) async {
  var packageConfigFile = await checkForPackageConfigJsonFile(directory);
  if (packageConfigFile != null) {
    return await readPackageConfigJsonFile(packageConfigFile);
  }
  packageConfigFile = await checkForDotPackagesFile(directory);
  if (packageConfigFile != null) {
    return await readDotPackagesFile(packageConfigFile);
  }
  return null;
}

Future<File> /*?*/ checkForPackageConfigJsonFile(Directory directory) async {
  assert(directory.isAbsolute);
  var file =
      File(path.join(directory.path, ".dart_tool", "package_config.json"));
  if (await file.exists()) return file;
  return null;
}

Future<File /*?*/ > checkForDotPackagesFile(Directory directory) async {
  var file = File(path.join(directory.path, ".packages"));
  if (await file.exists()) return file;
  return null;
}

Future<Uint8List /*?*/ > _loadFile(File file) async {
  Uint8List bytes;
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
