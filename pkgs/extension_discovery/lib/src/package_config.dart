// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show File, IOException;
import 'expect_json.dart';

typedef PackageConfigEntry = ({String name, Uri rootUri, Uri packageUri});
typedef PackageConfig = List<PackageConfigEntry>;

/// Searches in [packageDir] and all directories above for a
/// `.dart_tool/package_config.json` file. Returns the Uri of that file if
/// found.
///
/// Returns `null` if no file was found.
Uri? findPackageConfig(Uri packageDir) {
  if (!packageDir.isScheme('file')) {
    throw ArgumentError(
      'Expected [packageDir] to be a file URI, got $packageDir',
    );
  }
  if (!packageDir.path.endsWith('/')) {
    packageDir = packageDir.replace(path: '${packageDir.path}/');
  }
  while (true) {
    final packageConfigCandidate =
        packageDir.resolve('.dart_tool/package_config.json');
    try {
      if (File.fromUri(packageConfigCandidate).existsSync()) {
        return packageConfigCandidate;
      }
    } on IOException {
      return null; // if we get a permission error, etc, we return null
    }
    final next = packageDir.resolve('..');
    if (next == packageDir) return null;
    packageDir = next;
  }
}

/// Load list of packages and associated URIs from the
/// `.dart_tool/package_config.json` file in [packageConfigFile].
Future<PackageConfig> loadPackageConfig(
  File packageConfigFile,
) async {
  try {
    final packageConfig = decodeJsonMap(await packageConfigFile.readAsString());
    if (packageConfig.expectNumber('configVersion') != 2) {
      throw const FormatException('"configVersion" must be 2');
    }
    return packageConfig.expectListObjects('packages').map((p) {
      final rootUri = p.expectUri('rootUri').asDirectory();
      return (
        name: p.expectString('name'),
        rootUri: rootUri,
        packageUri: p.optionalUri('packageUri')?.asDirectory() ?? rootUri,
      );
    }).toList();
  } on IOException catch (e) {
    if (!packageConfigFile.existsSync()) {
      throw packageConfigNotFound(packageConfigFile.uri);
    }
    throw packageConfigIOException(e);
  } on FormatException catch (e) {
    throw packageConfigInvalid(packageConfigFile.uri, e);
  }
}

/// Thrown, if the `.dart_tool/package_config.json` cannot be found or parsing
/// it fails.
///
/// This could be because the `package_config.json` file is missing or simply
/// invalid.
///
/// Mostly, this will happen if dependencies are not resolved, the solution is
/// call `dart pub get`.
final class PackageConfigException implements Exception {
  final String message;
  PackageConfigException._(this.message);

  @override
  String toString() => message;
}

PackageConfigException packageConfigNotFound(Uri packageConfigUri) =>
    PackageConfigException._(
      'package_config.json not found at: "$packageConfigUri"',
    );

PackageConfigException packageConfigInvalid(
        Uri packageConfigUri, FormatException e) =>
    PackageConfigException._(
      'Invalid package_config.json found at "$packageConfigUri": $e',
    );

PackageConfigException packageConfigIOException(IOException e) =>
    PackageConfigException._(
      'Failed to read package_config.json: $e',
    );

extension on Uri {
  Uri asDirectory() => replace(
        pathSegments: pathSegments.lastOrNull != ''
            ? pathSegments.followedBy([''])
            : pathSegments,
      );
}
