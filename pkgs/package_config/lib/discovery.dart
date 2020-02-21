// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Deprecated("Use the package_config.json based API")
library package_config.discovery;

import "dart:async";
import "dart:io";
import "dart:typed_data" show Uint8List;

import "package:path/path.dart" as path;

import "packages.dart";
import "packages_file.dart" as pkgfile show parse;
import "src/packages_impl.dart";
import "src/packages_io_impl.dart";

/// Reads a package resolution file and creates a [Packages] object from it.
///
/// The [packagesFile] must exist and be loadable.
/// Currently that means the URI must have a `file`, `http` or `https` scheme,
/// and that the file can be loaded and its contents parsed correctly.
///
/// If the [loader] is provided, it is used to fetch non-`file` URIs, and
/// it can support other schemes or set up more complex HTTP requests.
///
/// This function can be used to load an explicitly configured package
/// resolution file, for example one specified using a `--packages`
/// command-line parameter.
Future<Packages> loadPackagesFile(Uri packagesFile,
    {Future<List<int>> loader(Uri uri)}) async {
  Packages parseBytes(List<int> bytes) {
    return MapPackages(pkgfile.parse(bytes, packagesFile));
  }

  if (packagesFile.scheme == "file") {
    return parseBytes(await File.fromUri(packagesFile).readAsBytes());
  }
  if (loader == null) {
    return parseBytes(await _httpGet(packagesFile));
  }
  return parseBytes(await loader(packagesFile));
}

/// Create a [Packages] object for a package directory.
///
/// The [packagesDir] URI should refer to a directory.
/// Package names are resolved as relative to sub-directories of the
/// package directory.
///
/// This function can be used for explicitly configured package directories,
/// for example one specified using a `--package-root` comand-line parameter.
Packages getPackagesDirectory(Uri packagesDir) {
  if (packagesDir.scheme == "file") {
    return FilePackagesDirectoryPackages(Directory.fromUri(packagesDir));
  }
  if (!packagesDir.path.endsWith('/')) {
    packagesDir = packagesDir.replace(path: packagesDir.path + '/');
  }
  return NonFilePackagesDirectoryPackages(packagesDir);
}

/// Discover the package configuration for a Dart script.
///
/// The [baseUri] points to either the Dart script or its directory.
/// A package resolution strategy is found by going through the following steps,
/// and stopping when something is found.
///
/// * Check if a `.packages` file exists in the same directory.
/// * If `baseUri`'s scheme is not `file`, then assume a `packages` directory
///   in the same directory, and resolve packages relative to that.
/// * If `baseUri`'s scheme *is* `file`:
///   * Check if a `packages` directory exists.
///   * Otherwise check each successive parent directory of `baseUri` for a
///     `.packages` file.
///
/// If any of these tests succeed, a `Packages` class is returned.
/// Returns the constant [noPackages] if no resolution strategy is found.
///
/// This function currently only supports `file`, `http` and `https` URIs.
/// It needs to be able to load a `.packages` file from the URI, so only
/// recognized schemes are accepted.
///
/// To support other schemes, or more complex HTTP requests,
/// an optional [loader] function can be supplied.
/// It's called to load the `.packages` file for a non-`file` scheme.
/// The loader function returns the *contents* of the file
/// identified by the URI it's given.
/// The content should be a UTF-8 encoded `.packages` file, and must return an
/// error future if loading fails for any reason.
Future<Packages> findPackages(Uri baseUri,
    {Future<List<int>> loader(Uri unsupportedUri)}) {
  if (baseUri.scheme == "file") {
    return Future<Packages>.sync(() => findPackagesFromFile(baseUri));
  } else if (loader != null) {
    return findPackagesFromNonFile(baseUri, loader: loader);
  } else if (baseUri.scheme == "http" || baseUri.scheme == "https") {
    return findPackagesFromNonFile(baseUri, loader: _httpGet);
  } else {
    return Future<Packages>.value(Packages.noPackages);
  }
}

/// Find the location of the package resolution file/directory for a Dart file.
///
/// Checks for a `.packages` file in the [workingDirectory].
/// If not found, checks for a `packages` directory in the same directory.
/// If still not found, starts checking parent directories for
/// `.packages` until reaching the root directory.
///
/// Returns a [File] object of a `.packages` file if one is found, or a
/// [Directory] object for the `packages/` directory if that is found.
FileSystemEntity _findPackagesFile(String workingDirectory) {
  var dir = Directory(workingDirectory);
  if (!dir.isAbsolute) dir = dir.absolute;
  if (!dir.existsSync()) {
    throw ArgumentError.value(
        workingDirectory, "workingDirectory", "Directory does not exist.");
  }
  File checkForConfigFile(Directory directory) {
    assert(directory.isAbsolute);
    var file = File(path.join(directory.path, ".packages"));
    if (file.existsSync()) return file;
    return null;
  }

  // Check for $cwd/.packages
  var packagesCfgFile = checkForConfigFile(dir);
  if (packagesCfgFile != null) return packagesCfgFile;
  // Check for $cwd/packages/
  var packagesDir = Directory(path.join(dir.path, "packages"));
  if (packagesDir.existsSync()) return packagesDir;
  // Check for cwd(/..)+/.packages
  var parentDir = dir.parent;
  while (parentDir.path != dir.path) {
    packagesCfgFile = checkForConfigFile(parentDir);
    if (packagesCfgFile != null) break;
    dir = parentDir;
    parentDir = dir.parent;
  }
  return packagesCfgFile;
}

/// Finds a package resolution strategy for a local Dart script.
///
/// The [fileBaseUri] points to either a Dart script or the directory of the
/// script. The `fileBaseUri` must be a `file:` URI.
///
/// This function first tries to locate a `.packages` file in the `fileBaseUri`
/// directory. If that is not found, it instead checks for the presence of
/// a `packages/` directory in the same place.
/// If that also fails, it starts checking parent directories for a `.packages`
/// file, and stops if it finds it.
/// Otherwise it gives up and returns [Packages.noPackages].
Packages findPackagesFromFile(Uri fileBaseUri) {
  var baseDirectoryUri = fileBaseUri;
  if (!fileBaseUri.path.endsWith('/')) {
    baseDirectoryUri = baseDirectoryUri.resolve(".");
  }
  var baseDirectoryPath = baseDirectoryUri.toFilePath();
  var location = _findPackagesFile(baseDirectoryPath);
  if (location == null) return Packages.noPackages;
  if (location is File) {
    var fileBytes = location.readAsBytesSync();
    var map = pkgfile.parse(fileBytes, Uri.file(location.path));
    return MapPackages(map);
  }
  assert(location is Directory);
  return FilePackagesDirectoryPackages(location);
}

/// Finds a package resolution strategy for a Dart script.
///
/// The [nonFileUri] points to either a Dart script or the directory of the
/// script.
/// The [nonFileUri] should not be a `file:` URI since the algorithm for
/// finding a package resolution strategy is more elaborate for `file:` URIs.
/// In that case, use [findPackagesFromFile].
///
/// This function first tries to locate a `.packages` file in the [nonFileUri]
/// directory. If that is not found, it instead assumes a `packages/` directory
/// in the same place.
///
/// By default, this function only works for `http:` and `https:` URIs.
/// To support other schemes, a loader must be provided, which is used to
/// try to load the `.packages` file. The loader should return the contents
/// of the requested `.packages` file as bytes, which will be assumed to be
/// UTF-8 encoded.
Future<Packages> findPackagesFromNonFile(Uri nonFileUri,
    {Future<List<int>> loader(Uri name)}) async {
  loader ??= _httpGet;
  var packagesFileUri = nonFileUri.resolve(".packages");

  try {
    var fileBytes = await loader(packagesFileUri);
    var map = pkgfile.parse(fileBytes, packagesFileUri);
    return MapPackages(map);
  } catch (_) {
    // Didn't manage to load ".packages". Assume a "packages/" directory.
    var packagesDirectoryUri = nonFileUri.resolve("packages/");
    return NonFilePackagesDirectoryPackages(packagesDirectoryUri);
  }
}

/// Fetches a file over http.
Future<List<int>> _httpGet(Uri uri) async {
  var client = HttpClient();
  var request = await client.getUrl(uri);
  var response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('${response.statusCode} ${response.reasonPhrase}',
        uri: uri);
  }
  var splitContent = await response.toList();
  var totalLength = 0;
  for (var list in splitContent) {
    totalLength += list.length;
  }
  var result = Uint8List(totalLength);
  var offset = 0;
  for (var contentPart in splitContent) {
    result.setRange(offset, offset + contentPart.length, contentPart);
    offset += contentPart.length;
  }
  return result;
}
